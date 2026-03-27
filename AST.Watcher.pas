unit AST.Watcher;

interface

uses
  SysUtils, Classes, Generics.Collections, Windows;

type
  TDirectoryWatcher = class(TThread)
  private type
    PFileNotifyInformation = ^TFileNotifyInformation;
    TFileNotifyInformation = record
      NextEntryOffset: DWORD;
      Action: DWORD;
      FileNameLength: DWORD;
      FileName: array[0..0] of WideChar;
    end;

    TRootWatch = record
      Handle: THandle;
      Overlapped: TOverlapped;
      Event: THandle;
      Buffer: array[0..65535] of Byte;
      Root: string;
    end;
  private
    FRoots: TArray<string>;
    FOnFileChanged: TProc<string>;
    FStopEvent: THandle;
    FWatches: TArray<TRootWatch>;
    FDebounce: TDictionary<string, TDateTime>;
    function IssueRead(var Watch: TRootWatch): Boolean;
    procedure ProcessNotifications(var Watch: TRootWatch; BytesTransferred: DWORD);
    procedure ProcessDebounceQueue;
    function IsDelphiFile(const FileName: string): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARoots: TArray<string>;
      AOnFileChanged: TProc<string>);
    destructor Destroy; override;
    procedure Stop;
  end;

implementation

const
  DEBOUNCE_MS = 500;
  FILE_NOTIFY_CHANGE_LAST_WRITE = $00000010;
  FILE_NOTIFY_CHANGE_FILE_NAME  = $00000001;

{ TDirectoryWatcher }

constructor TDirectoryWatcher.Create(const ARoots: TArray<string>;
  AOnFileChanged: TProc<string>);
begin
  inherited Create(True); // Create suspended
  FreeOnTerminate := False;
  FRoots := Copy(ARoots);
  FOnFileChanged := AOnFileChanged;
  FStopEvent := CreateEvent(nil, True, False, nil);
  FDebounce := TDictionary<string, TDateTime>.Create;
end;

destructor TDirectoryWatcher.Destroy;
begin
  Stop;
  CloseHandle(FStopEvent);
  FDebounce.Free;
  inherited;
end;

procedure TDirectoryWatcher.Stop;
begin
  if not Terminated then
  begin
    Terminate;
    SetEvent(FStopEvent);
    WaitFor;
  end;
end;

function TDirectoryWatcher.IsDelphiFile(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.pas') or (Ext = '.dpr') or (Ext = '.dpk');
end;

function TDirectoryWatcher.IssueRead(var Watch: TRootWatch): Boolean;
begin
  FillChar(Watch.Overlapped, SizeOf(TOverlapped), 0);
  Watch.Overlapped.hEvent := Watch.Event;
  Result := ReadDirectoryChangesW(
    Watch.Handle,
    @Watch.Buffer[0],
    SizeOf(Watch.Buffer),
    True, // watch subtree
    FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_FILE_NAME,
    nil,
    @Watch.Overlapped,
    nil
  );
  if not Result then
    WriteLn(ErrOutput, '[delphi-ast] Watcher: ReadDirectoryChangesW failed, error=' +
      IntToStr(GetLastError) + ' for ' + Watch.Root);
end;

procedure TDirectoryWatcher.ProcessNotifications(var Watch: TRootWatch;
  BytesTransferred: DWORD);
var
  Info: PFileNotifyInformation;
  Offset: DWORD;
  FileName, FullPath: string;
  FireTime: TDateTime;
begin
  if BytesTransferred = 0 then
    Exit;

  Offset := 0;
  repeat
    Info := PFileNotifyInformation(@Watch.Buffer[Offset]);
    SetString(FileName, Info^.FileName, Info^.FileNameLength div SizeOf(WideChar));

    if IsDelphiFile(FileName) then
    begin
      FullPath := LowerCase(IncludeTrailingPathDelimiter(Watch.Root) + FileName);
      FireTime := Now + (DEBOUNCE_MS / MSecsPerDay);
      FDebounce.AddOrSetValue(FullPath, FireTime);
    end;

    if Info^.NextEntryOffset = 0 then
      Break;
    Inc(Offset, Info^.NextEntryOffset);
  until False;
end;

procedure TDirectoryWatcher.ProcessDebounceQueue;
var
  Key: string;
  FireTime: TDateTime;
  Ready: TArray<string>;
  I: Integer;
begin
  if FDebounce.Count = 0 then
    Exit;

  SetLength(Ready, 0);
  for Key in FDebounce.Keys do
  begin
    FireTime := FDebounce[Key];
    if Now >= FireTime then
    begin
      SetLength(Ready, Length(Ready) + 1);
      Ready[High(Ready)] := Key;
    end;
  end;

  for I := 0 to High(Ready) do
  begin
    FDebounce.Remove(Ready[I]);
    try
      if Assigned(FOnFileChanged) then
        FOnFileChanged(Ready[I]);
    except
      // Swallow callback exceptions
    end;
  end;
end;

procedure TDirectoryWatcher.Execute;
var
  I: Integer;
  WaitHandles: array of THandle;
  WaitResult: DWORD;
  BytesTransferred: DWORD;
  WatchCount: Integer;
begin
  WatchCount := 0;
  SetLength(FWatches, Length(FRoots));

  for I := 0 to High(FRoots) do
  begin
    if not DirectoryExists(FRoots[I]) then
      Continue;

    FWatches[WatchCount].Root := FRoots[I];
    FWatches[WatchCount].Handle := CreateFile(
      PChar(FRoots[I]),
      FILE_LIST_DIRECTORY,
      FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
      nil,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
      0
    );

    if FWatches[WatchCount].Handle = INVALID_HANDLE_VALUE then
    begin
      WriteLn(ErrOutput, '[delphi-ast] Watcher: Cannot open directory ' + FRoots[I]);
      Continue;
    end;

    FWatches[WatchCount].Event := CreateEvent(nil, True, False, nil);
    IssueRead(FWatches[WatchCount]);
    Inc(WatchCount);
  end;

  SetLength(FWatches, WatchCount);

  if WatchCount = 0 then
  begin
    WriteLn(ErrOutput, '[delphi-ast] Watcher: No directories to watch');
    Exit;
  end;

  WriteLn(ErrOutput, '[delphi-ast] Watcher: Monitoring ' + IntToStr(WatchCount) + ' directories');

  // Build wait handle array: [StopEvent, Event0, Event1, ...]
  SetLength(WaitHandles, 1 + WatchCount);
  WaitHandles[0] := FStopEvent;
  for I := 0 to WatchCount - 1 do
    WaitHandles[1 + I] := FWatches[I].Event;

  while not Terminated do
  begin
    WaitResult := WaitForMultipleObjects(Length(WaitHandles), @WaitHandles[0], False, 200);

    if WaitResult = WAIT_OBJECT_0 then
      Break; // Stop event signaled

    if WaitResult = WAIT_FAILED then
    begin
      Sleep(200); // Prevent busy-loop on persistent failure
      Continue;
    end;

    if (WaitResult >= WAIT_OBJECT_0 + 1) and
       (WaitResult < WAIT_OBJECT_0 + 1 + DWORD(WatchCount)) then
    begin
      I := WaitResult - WAIT_OBJECT_0 - 1;
      if GetOverlappedResult(FWatches[I].Handle, FWatches[I].Overlapped,
        BytesTransferred, False) then
      begin
        ProcessNotifications(FWatches[I], BytesTransferred);
      end;
      ResetEvent(FWatches[I].Event);
      IssueRead(FWatches[I]);
    end;

    ProcessDebounceQueue;
  end;

  // Cleanup
  for I := 0 to WatchCount - 1 do
  begin
    CancelIo(FWatches[I].Handle);
    CloseHandle(FWatches[I].Event);
    CloseHandle(FWatches[I].Handle);
  end;
end;

end.
