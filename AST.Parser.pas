unit AST.Parser;

interface

uses
  SysUtils, Classes, Generics.Collections, IOUtils, System.SyncObjs,
  DelphiAST, DelphiAST.Classes, DelphiAST.Consts,
  SimpleParser.Lexer.Types;

type
  TCachedTree = record
    Node: TSyntaxNode;
    ModifiedAt: TDateTime;
  end;

  TSimpleIncludeHandler = class(TInterfacedObject, IIncludeHandler)
  private
    FRoots: TArray<string>;
  public
    constructor Create(const AProjectRoot: string); overload;
    constructor Create(const ARoots: TArray<string>); overload;
    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
  end;

  TParseState = (psIdle, psParsing);

  TParseStatus = record
    State: TParseState;
    TotalFiles: Integer;
    ParsedFiles: Integer;
    CachedFiles: Integer;
    FailedFiles: Integer;
  end;

  TASTParser = class
  private
    FRoots: TArray<string>;
    FCache: TDictionary<string, TCachedTree>;
    FIncludeHandler: IIncludeHandler;
    FLock: TLightweightMREW;
    FCacheDir: string;
    FWatcher: TObject;
    FParseState: Integer;
    FHasParsed: Integer;
    FTotalFiles: Integer;
    FParsedFiles: Integer;
    FCachedFiles: Integer;
    FFailedFiles: Integer;
    FProjectFiles: TList<string>;
    FRewalking: Integer;
    FProjectFilesLock: TLightweightMREW;
    FParseThread: TThread;
    FParseThreadLock: TCriticalSection;
    FCancelled: Integer;
    FFileIndex: TDictionary<string, string>;

    procedure WaitForParseThread;
    procedure BuildFileIndex;

    function GetProjectRoot: string;
    function ResolveUnitFile(const UnitName: string): string;
    procedure ParseProjectFiles;
    procedure InitCacheDir;
    function GetCacheFilePath(const Key: string): string;
    procedure SaveCacheEntryToDisk(const Key: string; const Entry: TCachedTree);
    function TryLoadCacheEntryFromDisk(const CacheFile: string;
      out Key: string; out Entry: TCachedTree): Boolean;
    procedure LoadPersistedCache;
    procedure HandleFileChanged(const AFullPath: string);
  public
    constructor Create(const AProjectRoot: string); overload;
    constructor Create(const ARoots: TArray<string>); overload;
    destructor Destroy; override;

    function ListFiles(const NameFilter: string = ''): TArray<string>;
    function ParseFile(const AFileName: string): TSyntaxNode;
    procedure ParseAllFiles;
    function GetAllTrees: TArray<TPair<string, TSyntaxNode>>;
    procedure ClearCache;
    procedure InvalidateFile(const AFullPath: string);
    function ResolveFilePath(const AFileName: string): string;

    procedure Reconfigure(const ARoots: TArray<string>);
    function IsConfigured: Boolean;
    function IsParsing: Boolean;
    function IsReady: Boolean;
    function GetParseStatus: TParseStatus;

    property ProjectRoot: string read GetProjectRoot;
  end;

implementation

uses
  System.Hash, AST.Serialize, AST.Watcher, AST.Query;

{ TSimpleIncludeHandler }

constructor TSimpleIncludeHandler.Create(const AProjectRoot: string);
begin
  inherited Create;
  FRoots := TArray<string>.Create(AProjectRoot);
end;

constructor TSimpleIncludeHandler.Create(const ARoots: TArray<string>);
begin
  inherited Create;
  FRoots := Copy(ARoots);
end;

function TSimpleIncludeHandler.GetIncludeFileContent(
  const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  Dir, FullPath: string;
  I: Integer;
begin
  Result := False;
  Content := '';
  FileName := '';

  // Search parent directory first
  Dir := ExtractFilePath(ParentFileName);
  FullPath := TPath.Combine(Dir, IncludeName);
  if FileExists(FullPath) then
  begin
    FileName := FullPath;
    Content := TFile.ReadAllText(FullPath);
    Exit(True);
  end;

  // Then search all roots
  for I := 0 to High(FRoots) do
  begin
    FullPath := TPath.Combine(FRoots[I], IncludeName);
    if FileExists(FullPath) then
    begin
      FileName := FullPath;
      Content := TFile.ReadAllText(FullPath);
      Exit(True);
    end;
  end;
end;

{ TASTParser }

function TASTParser.GetProjectRoot: string;
begin
  if Length(FRoots) > 0 then
    Result := FRoots[0]
  else
    Result := '';
end;

constructor TASTParser.Create(const AProjectRoot: string);
begin
  Create(TArray<string>.Create(AProjectRoot));
end;

constructor TASTParser.Create(const ARoots: TArray<string>);
var
  I: Integer;
  Thread: TThread;
begin
  inherited Create;
  FCache := TDictionary<string, TCachedTree>.Create;
  FProjectFiles := TList<string>.Create;
  FFileIndex := TDictionary<string, string>.Create;
  FRewalking := 0;
  FParseThreadLock := TCriticalSection.Create;
  FCancelled := 0;

  if Length(ARoots) > 0 then
  begin
    SetLength(FRoots, Length(ARoots));
    for I := 0 to High(ARoots) do
      FRoots[I] := IncludeTrailingPathDelimiter(ExpandFileName(ARoots[I]));
    FIncludeHandler := TSimpleIncludeHandler.Create(FRoots);
    InitCacheDir;

    // Start file watcher
    FWatcher := TDirectoryWatcher.Create(FRoots,
      procedure(APath: string)
      begin
        HandleFileChanged(APath);
      end);
    TDirectoryWatcher(FWatcher).Start;

    // Eager-parse project files (dependency-driven) in background - tracked thread
    Thread := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          ParseProjectFiles;
        except
          on E: Exception do
            WriteLn(ErrOutput, '[delphi-ast] Background parse failed: ' + E.Message);
        end;
      end);
    Thread.FreeOnTerminate := False;
    FParseThreadLock.Enter;
    try
      FParseThread := Thread;
    finally
      FParseThreadLock.Leave;
    end;
    Thread.Start;
  end;
end;

destructor TASTParser.Destroy;
var
  Entry: TCachedTree;
begin
  // Stop watcher first
  if FWatcher <> nil then
  begin
    TDirectoryWatcher(FWatcher).Stop;
    FWatcher.Free;
  end;

  // Wait for any background parse thread to complete
  WaitForParseThread;

  FIncludeHandler := nil;
  FLock.BeginWrite;
  try
    for Entry in FCache.Values do
      Entry.Node.Free;
    FCache.Free;
    FProjectFiles.Free;
    FFileIndex.Free;
  finally
    FLock.EndWrite;
  end;

  FParseThreadLock.Free;
  inherited;
end;

procedure TASTParser.InitCacheDir;
var
  Joined, HashStr: string;
  I: Integer;
begin
  Joined := '';
  for I := 0 to High(FRoots) do
  begin
    if I > 0 then
      Joined := Joined + ';';
    Joined := Joined + LowerCase(FRoots[I]);
  end;
  HashStr := Copy(THashMD5.GetHashString(Joined), 1, 12);
  FCacheDir := IncludeTrailingPathDelimiter(
    TPath.Combine(TPath.GetTempPath, 'DelphiAST_MCP_' + HashStr));
  if not DirectoryExists(FCacheDir) then
    ForceDirectories(FCacheDir);
end;

function TASTParser.GetCacheFilePath(const Key: string): string;
begin
  Result := TPath.Combine(FCacheDir,
    THashMD5.GetHashString(LowerCase(Key)) + '.dast');
end;

procedure TASTParser.SaveCacheEntryToDisk(const Key: string;
  const Entry: TCachedTree);
var
  CacheFile, TmpFile: string;
begin
  try
    CacheFile := GetCacheFilePath(Key);
    TmpFile := CacheFile + '.tmp';
    if TFullASTSerializer.SaveToFile(TmpFile, Entry.Node, Entry.ModifiedAt, Key) then
    begin
      if FileExists(CacheFile) then
        DeleteFile(CacheFile);
      RenameFile(TmpFile, CacheFile);
    end
    else
    begin
      if FileExists(TmpFile) then
        DeleteFile(TmpFile);
    end;
  except
    on E: Exception do
      WriteLn(ErrOutput, '[delphi-ast] Failed to save cache for ' + Key + ': ' + E.Message);
  end;
end;

function TASTParser.TryLoadCacheEntryFromDisk(const CacheFile: string;
  out Key: string; out Entry: TCachedTree): Boolean;
var
  Root: TSyntaxNode;
  ModifiedAt: TDateTime;
  SourcePath: string;
  FileTime: TDateTime;
begin
  Result := False;
  Key := '';
  Entry.Node := nil;
  Entry.ModifiedAt := 0;

  try
    if not TFullASTSerializer.LoadFromFile(CacheFile, Root, ModifiedAt, SourcePath) then
    begin
      DeleteFile(CacheFile);
      Exit;
    end;

    // Validate source file still exists and timestamp matches
    if not FileExists(SourcePath) then
    begin
      Root.Free;
      DeleteFile(CacheFile);
      Exit;
    end;

    FileTime := TFile.GetLastWriteTime(SourcePath);
    if FileTime > ModifiedAt then
    begin
      Root.Free;
      DeleteFile(CacheFile);
      Exit;
    end;

    // Canonicalize path to match ParseFile's key generation
    Key := LowerCase(TPath.GetFullPath(SourcePath));
    Entry.Node := Root;
    Entry.ModifiedAt := ModifiedAt;
    Result := True;
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, '[delphi-ast] Failed to load cache file ' + CacheFile + ': ' + E.Message);
      try
        DeleteFile(CacheFile);
      except
      end;
    end;
  end;
end;

procedure TASTParser.LoadPersistedCache;
var
  Files: TArray<string>;
  F, Key: string;
  Entry: TCachedTree;
  Loaded: Integer;
begin
  if not DirectoryExists(FCacheDir) then
    Exit;

  Files := TDirectory.GetFiles(FCacheDir, '*.dast');
  Loaded := 0;

  for F in Files do
  begin
    if TryLoadCacheEntryFromDisk(F, Key, Entry) then
    begin
      FLock.BeginWrite;
      try
        if not FCache.ContainsKey(Key) then
        begin
          WriteLn(ErrOutput, '[delphi-ast] Adding '+key+' to cache');
          FCache.Add(Key, Entry);
          Inc(Loaded);
        end else
        begin
          WriteLn(ErrOutput, '[delphi-ast] '+key+' already in cache');
          Entry.Node.Free; // Already loaded by another path
        end;
      finally
        FLock.EndWrite;
      end;
    end;
  end;

  if Loaded > 0 then
    WriteLn(ErrOutput, '[delphi-ast] Loaded ' + IntToStr(Loaded) + ' files from disk cache');
end;

procedure TASTParser.HandleFileChanged(const AFullPath: string);
var
  Thread: TThread;
begin
  WriteLn(ErrOutput, '[delphi-ast] File changed: ' + AFullPath);
  InvalidateFile(AFullPath);

  // Re-parse the changed file immediately
  try
    ParseFile(AFullPath);
    WriteLn(ErrOutput, '[delphi-ast] Re-parsed: ' + AFullPath);
  except
    on E: Exception do
      WriteLn(ErrOutput, '[delphi-ast] Failed to re-parse ' + AFullPath + ': ' + E.Message);
  end;

  // Re-walk dependencies to handle added/removed uses clauses
  // Use CompareExchange to prevent concurrent re-walks
  if TInterlocked.CompareExchange(FRewalking, 1, 0) = 0 then
  begin
    // Wait for any running parse thread to complete first
    WaitForParseThread;

    // Spawn tracked thread for re-walk
    Thread := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          ParseProjectFiles;
        finally
          TInterlocked.Exchange(FRewalking, 0);
        end;
      end);
    Thread.FreeOnTerminate := False;
    FParseThreadLock.Enter;
    try
      FParseThread := Thread;
    finally
      FParseThreadLock.Leave;
    end;
    Thread.Start;
  end
  else
  begin
    WriteLn(ErrOutput, '[delphi-ast] Re-walk already in progress, skipping');
  end;
end;

procedure TASTParser.Reconfigure(const ARoots: TArray<string>);
var
  Entry: TCachedTree;
  I: Integer;
  Thread: TThread;
begin
  // 1. Stop existing watcher
  if FWatcher <> nil then
  begin
    TDirectoryWatcher(FWatcher).Stop;
    FreeAndNil(FWatcher);
  end;

  // 2. Cancel and wait for any running parse thread
  TInterlocked.Exchange(FCancelled, 1);
  WaitForParseThread;
  TInterlocked.Exchange(FCancelled, 0);

  // 3. Clear all cached trees
  FLock.BeginWrite;
  try
    for Entry in FCache.Values do
      Entry.Node.Free;
    FCache.Clear;
  finally
    FLock.EndWrite;
  end;

  // 4. Set new roots
  SetLength(FRoots, Length(ARoots));
  for I := 0 to High(ARoots) do
    FRoots[I] := IncludeTrailingPathDelimiter(ExpandFileName(ARoots[I]));

  // 5. Reinitialize
  FIncludeHandler := TSimpleIncludeHandler.Create(FRoots);
  InitCacheDir;

  // Reset parse state - will be ready again after ParseAllFiles completes
  TInterlocked.Exchange(FHasParsed, 0);

  // 6. Start new watcher
  FWatcher := TDirectoryWatcher.Create(FRoots,
    procedure(APath: string)
    begin
      HandleFileChanged(APath);
    end);
  TDirectoryWatcher(FWatcher).Start;

  // 7. Background parse - tracked thread
  Thread := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        ParseProjectFiles;
      except
        on E: Exception do
          WriteLn(ErrOutput, '[delphi-ast] Background parse failed: ' + E.Message);
      end;
    end);
  Thread.FreeOnTerminate := False;
  FParseThreadLock.Enter;
  try
    FParseThread := Thread;
  finally
    FParseThreadLock.Leave;
  end;
  Thread.Start;
end;

function TASTParser.IsConfigured: Boolean;
begin
  Result := Length(FRoots) > 0;
end;

function TASTParser.IsParsing: Boolean;
begin
  Result := FParseState = Integer(psParsing);
end;

function TASTParser.IsReady: Boolean;
begin
  Result := (FHasParsed = 1) and (FParseState = Integer(psIdle));
end;

function TASTParser.GetParseStatus: TParseStatus;
begin
  Result.State       := TParseState(FParseState);
  Result.TotalFiles  := FTotalFiles;
  Result.ParsedFiles := FParsedFiles;
  Result.CachedFiles := FCachedFiles;
  Result.FailedFiles := FFailedFiles;
end;

procedure TASTParser.WaitForParseThread;
var
  Thread: TThread;
begin
  FParseThreadLock.Enter;
  try
    Thread := FParseThread;
    FParseThread := nil;
  finally
    FParseThreadLock.Leave;
  end;
  if Thread <> nil then
  begin
    Thread.WaitFor;
    Thread.Free;
  end;
end;

function TASTParser.ListFiles(const NameFilter: string): TArray<string>;
var
  Files: TStringList;
  FullPath, RelPath, LowerFilter, Root, Ext: string;
  I: Integer;
begin
  Files := TStringList.Create;
  try
    Files.Sorted := True;
    Files.Duplicates := dupIgnore;
    LowerFilter := LowerCase(NameFilter);

    // Get the project root for relative path calculation
    Root := '';
    if Length(FRoots) > 0 then
      Root := FRoots[0];

    // Return only project files discovered via dependency walk (protected by lock)
    FProjectFilesLock.BeginRead;
    try
      for FullPath in FProjectFiles do
      begin
        Ext := LowerCase(ExtractFileExt(FullPath));
        if (Ext <> '.pas') and (Ext <> '.dpr') and (Ext <> '.dpk') then
          Continue;

        RelPath := FullPath;
        if (Root <> '') and FullPath.StartsWith(Root, True) then
          RelPath := FullPath.Substring(Length(Root));

        if (LowerFilter = '') or
           (Pos(LowerFilter, LowerCase(ExtractFileName(FullPath))) > 0) then
          Files.Add(RelPath);
      end;
    finally
      FProjectFilesLock.EndRead;
    end;

    Result := Files.ToStringArray;
  finally
    Files.Free;
  end;
end;

function TASTParser.ResolveFilePath(const AFileName: string): string;
var
  I: Integer;
  FullPath: string;
begin
  if Length(FRoots) = 0 then
    raise Exception.Create('No project configured. Call set_project first.');

  if not TPath.IsRelativePath(AFileName) then
    Exit(AFileName);

  // Check each root for file existence
  for I := 0 to High(FRoots) do
  begin
    FullPath := TPath.Combine(FRoots[I], AFileName);
    if FileExists(FullPath) then
      Exit(FullPath);
  end;

  // Fall back to first root
  Result := TPath.Combine(FRoots[0], AFileName);
end;

function TASTParser.ParseFile(const AFileName: string): TSyntaxNode;
var
  FullPath, Key: string;
  Entry: TCachedTree;
  FileTime: TDateTime;
begin
  FullPath := ResolveFilePath(AFileName);
  FullPath := TPath.GetFullPath(FullPath);  // Canonicalize path to avoid duplicate cache entries
  Key := LowerCase(FullPath);

  // Fast path: read lock check
  FLock.BeginRead;
  try
    if FCache.TryGetValue(Key, Entry) then
    begin
      FileTime := TFile.GetLastWriteTime(FullPath);
      if FileTime <= Entry.ModifiedAt then
        Exit(Entry.Node);
    end;
  finally
    FLock.EndRead;
  end;

  // Slow path: parse outside lock
  if not FileExists(FullPath) then
    raise Exception.CreateFmt('File not found: %s', [FullPath]);

  Entry.Node := TPasSyntaxTreeBuilder.Run(FullPath, False, FIncludeHandler);
  Entry.ModifiedAt := TFile.GetLastWriteTime(FullPath);

  // Write lock: store result
  FLock.BeginWrite;
  try
    // Double-check: another thread may have parsed it
    if FCache.ContainsKey(Key) then
    begin
      var OldEntry := FCache[Key];
      OldEntry.Node.Free;
      FCache.Remove(Key);
    end;
    FCache.Add(Key, Entry);
    Result := Entry.Node;
  finally
    FLock.EndWrite;
  end;

  // Save to disk cache (outside lock)
  SaveCacheEntryToDisk(Key, Entry);
end;

procedure TASTParser.ParseAllFiles;
var
  Files: TArray<string>;
  F, FullPath, Key: string;
  Parsed, Failed, Cached: Integer;
  Entry: TCachedTree;
  AlreadyCached: Boolean;
begin
  // Set parsing state and reset counters
  TInterlocked.Exchange(FParseState, Integer(psParsing));
  TInterlocked.Exchange(FParsedFiles, 0);
  TInterlocked.Exchange(FCachedFiles, 0);
  TInterlocked.Exchange(FFailedFiles, 0);
  TInterlocked.Exchange(FTotalFiles, 0);

  Parsed := 0;
  Failed := 0;
  Cached := 0;
  try
    // First load persisted cache from disk
    LoadPersistedCache;

    Files := ListFiles('');
    TInterlocked.Exchange(FTotalFiles, Length(Files));

    for F in Files do
    begin
      try
        FullPath := ResolveFilePath(F);
        Key := LowerCase(FullPath);

        // Check if already in cache with fresh timestamp
        AlreadyCached := False;
        FLock.BeginRead;
        try
          if FCache.TryGetValue(Key, Entry) then
          begin
            if FileExists(FullPath) and
               (TFile.GetLastWriteTime(FullPath) <= Entry.ModifiedAt) then
            begin
              AlreadyCached := True;
              Inc(Cached);
              TInterlocked.Increment(FCachedFiles);
            end;
          end;
        finally
          FLock.EndRead;
        end;

        if not AlreadyCached then
        begin
          ParseFile(F);
          Inc(Parsed);
          TInterlocked.Increment(FParsedFiles);
        end;
      except
        on E: Exception do
        begin
          Inc(Failed);
          TInterlocked.Increment(FFailedFiles);
          WriteLn(ErrOutput, '[delphi-ast] Failed to parse ' + F + ': ' + E.Message);
        end;
      end;
    end;

    WriteLn(ErrOutput, '[delphi-ast] Eager parse complete: ' +
      IntToStr(Cached) + ' from cache, ' +
      IntToStr(Parsed) + ' parsed, ' +
      IntToStr(Failed) + ' failed');
  finally
    TInterlocked.Exchange(FParseState, Integer(psIdle));
    TInterlocked.Exchange(FHasParsed, 1);
  end;
end;

function TASTParser.ResolveUnitFile(const UnitName: string): string;
var
  SearchKey: string;
begin
  // O(1) lookup using pre-built file index
  SearchKey := LowerCase(UnitName + '.pas');
  if not FFileIndex.TryGetValue(SearchKey, Result) then
    Result := '';
end;

procedure TASTParser.BuildFileIndex;
var
  I: Integer;
  Files: TArray<string>;
  F, FileName: string;
begin
  FFileIndex.Clear;
  for I := 0 to High(FRoots) do
  begin
    try
      Files := TDirectory.GetFiles(FRoots[I], '*.pas');
      for F in Files do
      begin
        FileName := LowerCase(ExtractFileName(F));
        if not FFileIndex.ContainsKey(FileName) then
          FFileIndex.Add(FileName, TPath.GetFullPath(F));
      end;
      Files := TDirectory.GetFiles(FRoots[I], '*.dpr');
      for F in Files do
      begin
        FileName := LowerCase(ExtractFileName(F));
        if not FFileIndex.ContainsKey(FileName) then
          FFileIndex.Add(FileName, TPath.GetFullPath(F));
      end;
    except
      on E: Exception do
        WriteLn(ErrOutput, '[delphi-ast] BuildFileIndex error for ' + FRoots[I] + ': ' + E.Message);
    end;
  end;
  WriteLn(ErrOutput, '[delphi-ast] File index built: ' + IntToStr(FFileIndex.Count) + ' files');
end;

procedure TASTParser.ParseProjectFiles;
var
  DPRFiles: TArray<string>;
  DPR, FullPath, UnitFile, Key: string;
  Queue: TQueue<string>;
  Visited: TDictionary<string, Boolean>;
  UnitNames: TArray<string>;
  UnitName: string;
  Tree: TSyntaxNode;
  Parsed, Failed, Cached: Integer;
  Entry: TCachedTree;
  AlreadyCached: Boolean;
begin
  // Set parsing state and reset counters
  TInterlocked.Exchange(FParseState, Integer(psParsing));
  TInterlocked.Exchange(FParsedFiles, 0);
  TInterlocked.Exchange(FCachedFiles, 0);
  TInterlocked.Exchange(FFailedFiles, 0);
  TInterlocked.Exchange(FTotalFiles, 0);

  Parsed := 0;
  Failed := 0;
  Cached := 0;

  // Clear project files list (protected by lock)
  FProjectFilesLock.BeginWrite;
  try
    FProjectFiles.Clear;
  finally
    FProjectFilesLock.EndWrite;
  end;

  // Load persisted cache from disk first
  LoadPersistedCache;

  // Build filename-to-path index for O(1) unit resolution
  BuildFileIndex;

  // Find all DPR files in the project root (first root only)
  if Length(FRoots) = 0 then
  begin
    TInterlocked.Exchange(FParseState, Integer(psIdle));
    TInterlocked.Exchange(FHasParsed, 1);
    Exit;
  end;

  DPRFiles := TDirectory.GetFiles(FRoots[0], '*.dpr');

  if Length(DPRFiles) = 0 then
    raise Exception.Create('No .dpr files found in project root: ' + FRoots[0]);

  Queue := TQueue<string>.Create;
  Visited := TDictionary<string, Boolean>.Create;
  try
    // Add all DPR files to the queue
    for DPR in DPRFiles do
    begin
      FullPath := TPath.GetFullPath(DPR);
      Queue.Enqueue(FullPath);
      Visited.AddOrSetValue(LowerCase(FullPath), True);
    end;

    // BFS: process files and discover dependencies
    while Queue.Count > 0 do
    begin
      // Check for cancellation
      if FCancelled = 1 then
        Break;

      FullPath := Queue.Dequeue;
      Key := LowerCase(FullPath);

      try
        WriteLn(ErrOutput, '[delphi-ast] Checking: '+key);
        // Check if already in cache with fresh timestamp
        AlreadyCached := False;
        FLock.BeginRead;
        try
          if FCache.TryGetValue(Key, Entry) then
          begin
            if FileExists(FullPath) and
               (TFile.GetLastWriteTime(FullPath) <= Entry.ModifiedAt) then
            begin
              AlreadyCached := True;
              Inc(Cached);
              TInterlocked.Increment(FCachedFiles);
            end;
          end;
        finally
          FLock.EndRead;
        end;

        // Add to project files (protected by lock)
        FProjectFilesLock.BeginWrite;
        try
          FProjectFiles.Add(FullPath);
        finally
          FProjectFilesLock.EndWrite;
        end;

        // Use cached tree directly when available, otherwise parse
        if AlreadyCached then
          Tree := Entry.Node
        else
        begin
          Tree := ParseFile(FullPath);
          Inc(Parsed);
          TInterlocked.Increment(FParsedFiles);
        end;

        // Extract uses clauses and add new units to queue
        if Tree <> nil then
        begin
          UnitNames := ExtractUnitNames(Tree);
          for UnitName in UnitNames do
          begin
            // Try to resolve unit name to a file path
            UnitFile := ResolveUnitFile(UnitName);
            if UnitFile <> '' then
            begin
              // If not already visited, add to queue
              if not Visited.ContainsKey(LowerCase(UnitFile)) then
              begin
                Visited.AddOrSetValue(LowerCase(UnitFile), True);
                Queue.Enqueue(UnitFile);
              end;
            end;
          end;
        end;
      except
        on E: Exception do
        begin
          Inc(Failed);
          TInterlocked.Increment(FFailedFiles);
          WriteLn(ErrOutput, '[delphi-ast] Failed to parse ' + FullPath + ': ' + E.Message);
        end;
      end;
    end;

    FProjectFilesLock.BeginRead;
    try
      TInterlocked.Exchange(FTotalFiles, FProjectFiles.Count);
    finally
      FProjectFilesLock.EndRead;
    end;

    WriteLn(ErrOutput, '[delphi-ast] Project parse complete: ' +
      IntToStr(Cached) + ' from cache, ' +
      IntToStr(Parsed) + ' parsed, ' +
      IntToStr(Failed) + ' failed');
  finally
    Queue.Free;
    Visited.Free;
    TInterlocked.Exchange(FParseState, Integer(psIdle));
    TInterlocked.Exchange(FHasParsed, 1);
  end;
end;

function TASTParser.GetAllTrees: TArray<TPair<string, TSyntaxNode>>;
var
  Pair: TPair<string, TCachedTree>;
  List: TList<TPair<string, TSyntaxNode>>;
begin
  List := TList<TPair<string, TSyntaxNode>>.Create;
  try
    FLock.BeginRead;
    try
      for Pair in FCache do
        List.Add(TPair<string, TSyntaxNode>.Create(Pair.Key, Pair.Value.Node));
    finally
      FLock.EndRead;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TASTParser.ClearCache;
var
  Entry: TCachedTree;
begin
  FLock.BeginWrite;
  try
    for Entry in FCache.Values do
      Entry.Node.Free;
    FCache.Clear;
  finally
    FLock.EndWrite;
  end;
end;

procedure TASTParser.InvalidateFile(const AFullPath: string);
var
  Key: string;
  Entry: TCachedTree;
  CacheFile: string;
begin
  Key := LowerCase(AFullPath);

  FLock.BeginWrite;
  try
    if FCache.TryGetValue(Key, Entry) then
    begin
      Entry.Node.Free;
      FCache.Remove(Key);
    end;
  finally
    FLock.EndWrite;
  end;

  // Delete disk cache file
  CacheFile := GetCacheFilePath(Key);
  try
    if FileExists(CacheFile) then
      DeleteFile(CacheFile);
  except
  end;
end;

end.
