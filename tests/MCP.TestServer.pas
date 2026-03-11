unit MCP.TestServer;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient;

type
  EMCPTestError = class(Exception);

  TMCPTestServer = class
  private
    FProcessHandle: THandle;
    FProcessId: Cardinal;
    FURL: string;
    FProjectPath: string;
    FPort: Integer;
    FClient: THTTPClient;
    FRequestId: Integer;
    function NextId: Integer;
    function DoRequest(const Method: string; const Body: TStream = nil): TJSONValue;
    procedure WaitForReady(TimeoutMs: Integer = 15000);
    procedure DoHandshake;
    function GetResponseText(Response: IHTTPResponse): string;
    function JSONHasKey(Obj: TJSONObject; const Key: string): Boolean;
  public
    class var Instance: TMCPTestServer;
    constructor Create(const AProjectPath: string; APort: Integer = 3099);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function CallTool(const ToolName: string): TJSONValue; overload;
    function CallTool(const ToolName: string; const Args: TJSONObject;
      ExpectError: Boolean): TJSONValue; overload;
    property URL: string read FURL;
    property ProjectPath: string read FProjectPath;
  end;

implementation

uses
  WinAPI.Windows, System.StrUtils;

constructor TMCPTestServer.Create(const AProjectPath: string; APort: Integer);
begin
  inherited Create;
  FProjectPath := AProjectPath;
  FPort := APort;
  FURL := Format('http://localhost:%d/mcp', [APort]);
  FClient := THTTPClient.Create;
  FRequestId := 1;
end;

destructor TMCPTestServer.Destroy;
begin
  Stop;
  FClient.Free;
  inherited;
end;

function TMCPTestServer.NextId: Integer;
begin
  Result := FRequestId;
  Inc(FRequestId);
end;

function TMCPTestServer.GetResponseText(Response: IHTTPResponse): string;
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create;
  try
    Stream.CopyFrom(Response.ContentStream, 0);
    Result := Stream.DataString;
  finally
    Stream.Free;
  end;
end;

function TMCPTestServer.JSONHasKey(Obj: TJSONObject; const Key: string): Boolean;
begin
  Result := Obj.GetValue(Key) <> nil;
end;

function TMCPTestServer.DoRequest(const Method: string; const Body: TStream): TJSONValue;
var
  Response: IHTTPResponse;
  JsonStr: string;
begin
  try
    Response := FClient.Post(FURL, Body);
  except
    on E: Exception do
      raise EMCPTestError.Create('HTTP POST failed: ' + E.Message);
  end;

  if Response = nil then
    raise EMCPTestError.Create('No response from server');

  if Response.StatusCode = 204 then
    Exit(nil); // initialized notification returns empty body

  if Response.StatusCode <> 200 then
    raise EMCPTestError.CreateFmt('HTTP %d: %s', [Response.StatusCode, GetResponseText(Response)]);

  try
    JsonStr := GetResponseText(Response);
    Result := TJSONObject.ParseJSONValue(JsonStr);
  except
    on E: Exception do
      raise EMCPTestError.Create('Failed to parse response: ' + E.Message);
  end;
end;

procedure TMCPTestServer.WaitForReady(TimeoutMs: Integer = 15000);
var
  StartTime: Cardinal;
  JSON: TJSONObject;
  Body: TStringStream;
begin
  StartTime := GetTickCount;
  while GetTickCount - StartTime < Cardinal(TimeoutMs) do
  begin
    try
      Body := TStringStream.Create('{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
        TEncoding.UTF8);
      try
        Body.Position := 0;
        JSON := DoRequest('initialize', Body) as TJSONObject;
        try
          if Assigned(JSON) and JSONHasKey(JSON, 'result') then
            Exit; // Server is ready
        finally
          JSON.Free;
        end;
      finally
        Body.Free;
      end;
    except
      // Server not ready yet, continue waiting
    end;
    Sleep(500);
  end;
  raise EMCPTestError.Create('Timeout waiting for server to be ready');
end;

procedure TMCPTestServer.DoHandshake;
var
  Body: TStringStream;
begin
  // Send initialized notification (fire and forget)
  Body := TStringStream.Create('{"jsonrpc":"2.0","id":1,"method":"initialized","params":{}}',
    TEncoding.UTF8);
  try
    Body.Position := 0;
    try
      DoRequest('initialized', Body);
    except
      // initialized returns 204, may throw - ignore
    end;
  finally
    Body.Free;
  end;
end;

procedure TMCPTestServer.Start;
var
  ExePath: string;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  CommandLine: string;
  SecurityAttr: TSecurityAttributes;
begin
  ExePath := ExpandFileName(ExtractFilePath(ParamStr(0)) + 'DelphiAST_MCP.exe');

  if not FileExists(ExePath) then
    raise EMCPTestError.CreateFmt('Server executable not found: %s', [ExePath]);

  SecurityAttr.nLength := SizeOf(TSecurityAttributes);
  SecurityAttr.lpSecurityDescriptor := nil;
  SecurityAttr.bInheritHandle := True;

  CommandLine := Format('"%s" "%s" --port %d', [ExePath, FProjectPath, FPort]);

  FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;

  if not CreateProcess(nil, PChar(CommandLine), @SecurityAttr, @SecurityAttr,
    False, CREATE_NO_WINDOW or CREATE_NEW_PROCESS_GROUP, nil, nil,
    StartupInfo, ProcessInfo) then
    raise EMCPTestError.Create('Failed to start server process');

  FProcessHandle := ProcessInfo.hProcess;
  FProcessId := ProcessInfo.dwProcessId;
  CloseHandle(ProcessInfo.hThread);

  // Wait for server to be ready
  WaitForReady;
  DoHandshake;
end;

procedure TMCPTestServer.Stop;
begin
  if FProcessHandle <> 0 then
  begin
    TerminateProcess(FProcessHandle, 0);
    WaitForSingleObject(FProcessHandle, 5000);
    CloseHandle(FProcessHandle);
    FProcessHandle := 0;
  end;
end;

function TMCPTestServer.CallTool(const ToolName: string): TJSONValue;
begin
  Result := CallTool(ToolName, nil, False);
end;

function TMCPTestServer.CallTool(const ToolName: string; const Args: TJSONObject;
  ExpectError: Boolean): TJSONValue;
var
  JSON: TJSONObject;
  Body: TStringStream;
  RequestStr: string;
  ResultObj: TJSONObject;
  Content: TJSONArray;
begin
  Result := nil;
  try
    // Build the request JSON manually to avoid ownership issues
    RequestStr := Format(
      '{"jsonrpc":"2.0","id":%d,"method":"tools/call","params":{"name":"%s","arguments":%s}}',
      [NextId, ToolName, IfThen(Assigned(Args), Args.ToString, '{}')]
    );
  except
    on E: Exception do
      raise EMCPTestError.Create('CallTool failed (request): ' + E.Message);
  end;

  try
    Body := TStringStream.Create(RequestStr, TEncoding.UTF8);
  except
    on E: Exception do
      raise EMCPTestError.Create('CallTool failed (stream): ' + E.Message);
  end;

  try
    try
      Body.Position := 0;
      JSON := DoRequest(ToolName, Body) as TJSONObject;
    except
      on E: Exception do
        raise EMCPTestError.Create('CallTool failed (request): ' + E.Message);
    end;

    if JSON = nil then
      raise EMCPTestError.Create('No JSON response');
    try
      if JSONHasKey(JSON, 'error') then
      begin
        if not ExpectError then
          raise EMCPTestError.Create('Error response: ' + JSON.ToString);
        Exit(TJSONObject.Create);
      end;

      ResultObj := JSON.GetValue<TJSONObject>('result');
      if not Assigned(ResultObj) then
        raise EMCPTestError.Create('No result in response');

      if JSONHasKey(ResultObj, 'isError') and ResultObj.GetValue<Boolean>('isError') and not ExpectError then
        raise EMCPTestError.Create('Tool returned error: ' + ResultObj.ToString);

      // Get content and extract inner JSON
      Content := ResultObj.GetValue<TJSONArray>('content');
      if not Assigned(Content) or (Content.Count = 0) then
        raise EMCPTestError.Create('No content in result');

      // Content is always [{type: "text", text: "<json>"}]
      // Extract the "text" field and parse it as JSON
      if Content[0] is TJSONObject then
      begin
        var TextObj: TJSONObject;
        TextObj := TJSONObject(Content[0]);
        var TextVal: TJSONValue;
        TextVal := TextObj.GetValue('text');
        if Assigned(TextVal) and (TextVal is TJSONString) then
        begin
          var TextStr: string;
          TextStr := TJSONString(TextVal).Value;
          try
            if TextStr <> '' then
              Result := TJSONObject.ParseJSONValue(TextStr)
            else
              Result := TJSONArray.Create;
          except
            Result := TJSONArray.Create;
          end;
        end
        else
          Result := TJSONArray.Create;
      end
      else if Content[0] is TJSONString then
        Result := TJSONObject.ParseJSONValue(TJSONString(Content[0]).Value)
      else
        Result := TJSONArray.Create;
    finally
      JSON.Free;
    end;
  finally
    Body.Free;
  end;
end;

end.
