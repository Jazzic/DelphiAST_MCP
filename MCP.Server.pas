unit MCP.Server;

interface

uses
  SysUtils, Classes, System.JSON, IdHTTPServer, IdContext, IdCustomHTTPServer,
  MCP.Tools, AST.Parser;

type
  TMCPServer = class
  private
    FTools: TMCPTools;
    FHTTPServer: TIdHTTPServer;
    FPort: Integer;
    FInitialized: Boolean;

    function BuildResponse(const Id: TJSONValue; ResultObj: TJSONValue): string;
    function BuildError(const Id: TJSONValue; Code: Integer; const Msg: string): string;
    function HandleMessage(const Line: string): string;

    function HandleInitialize(const Id: TJSONValue; Params: TJSONObject): string;
    function HandleToolsList(const Id: TJSONValue): string;
    function HandleToolsCall(const Id: TJSONValue; Params: TJSONObject): string;

    procedure OnCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);

    procedure Log(const Msg: string);
  public
    constructor Create(ATools: TMCPTools; APort: Integer = 3000);
    destructor Destroy; override;

    procedure Run;
  end;

implementation

uses
  IdGlobal;

const
  PROTOCOL_VERSION = '2024-11-05';
  SERVER_NAME = 'delphi-ast';
  SERVER_VERSION = '1.0.0';

  // JSON-RPC error codes
  ERR_PARSE_ERROR = -32700;
  ERR_INVALID_REQUEST = -32600;
  ERR_METHOD_NOT_FOUND = -32601;
  ERR_INTERNAL = -32603;

{ TMCPServer }

constructor TMCPServer.Create(ATools: TMCPTools; APort: Integer);
begin
  inherited Create;
  FTools := ATools;
  FPort := APort;
  FInitialized := False;

  FHTTPServer := TIdHTTPServer.Create(nil);
  FHTTPServer.DefaultPort := FPort;
  FHTTPServer.OnCommandGet := OnCommandGet;
  FHTTPServer.OnCommandOther := OnCommandGet;
end;

destructor TMCPServer.Destroy;
begin
  FHTTPServer.Active := False;
  FHTTPServer.Free;
  inherited;
end;

procedure TMCPServer.Log(const Msg: string);
begin
  try
    WriteLn('[delphi-ast] ' + Msg);
  except
    // Ignore console errors
  end;
end;

function TMCPServer.BuildResponse(const Id: TJSONValue; ResultObj: TJSONValue): string;
var
  Response: TJSONObject;
begin
  Response := TJSONObject.Create;
  try
    Response.AddPair('jsonrpc', '2.0');
    if Id <> nil then
      Response.AddPair('id', Id.Clone as TJSONValue)
    else
      Response.AddPair('id', TJSONNull.Create);
    Response.AddPair('result', ResultObj);
    Result := Response.ToJSON;
  finally
    Response.Free;
  end;
end;

function TMCPServer.BuildError(const Id: TJSONValue; Code: Integer; const Msg: string): string;
var
  Response, ErrorObj: TJSONObject;
begin
  Response := TJSONObject.Create;
  try
    Response.AddPair('jsonrpc', '2.0');
    if Id <> nil then
      Response.AddPair('id', Id.Clone as TJSONValue)
    else
      Response.AddPair('id', TJSONNull.Create);
    ErrorObj := TJSONObject.Create;
    ErrorObj.AddPair('code', TJSONNumber.Create(Code));
    ErrorObj.AddPair('message', Msg);
    Response.AddPair('error', ErrorObj);
    Result := Response.ToJSON;
  finally
    Response.Free;
  end;
end;

function TMCPServer.HandleInitialize(const Id: TJSONValue; Params: TJSONObject): string;
var
  ResultObj, ServerInfo, Capabilities, ToolsCap: TJSONObject;
begin
  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('protocolVersion', PROTOCOL_VERSION);

  ServerInfo := TJSONObject.Create;
  ServerInfo.AddPair('name', SERVER_NAME);
  ServerInfo.AddPair('version', SERVER_VERSION);
  ResultObj.AddPair('serverInfo', ServerInfo);

  Capabilities := TJSONObject.Create;
  ToolsCap := TJSONObject.Create;
  Capabilities.AddPair('tools', ToolsCap);
  ResultObj.AddPair('capabilities', Capabilities);

  FInitialized := True;
  Log('Initialized');
  Result := BuildResponse(Id, ResultObj);
end;

function TMCPServer.HandleToolsList(const Id: TJSONValue): string;
var
  ResultObj: TJSONObject;
begin
  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('tools', FTools.GetToolDefinitions);
  Result := BuildResponse(Id, ResultObj);
end;

function TMCPServer.HandleToolsCall(const Id: TJSONValue; Params: TJSONObject): string;
var
  ToolName: string;
  Arguments: TJSONObject;
  ToolResult: TJSONValue;
  ResultObj: TJSONObject;
  ContentArr: TJSONArray;
  ContentItem: TJSONObject;
  V: TJSONValue;
begin
  if not Params.TryGetValue<string>('name', ToolName) then
  begin
    Result := BuildError(Id, ERR_INVALID_REQUEST, 'Missing tool name');
    Exit;
  end;

  if Params.TryGetValue('arguments', V) and (V is TJSONObject) then
    Arguments := V as TJSONObject
  else
    Arguments := nil;

  try
    ToolResult := FTools.CallTool(ToolName, Arguments);
    try
      ResultObj := TJSONObject.Create;
      ContentArr := TJSONArray.Create;
      ContentItem := TJSONObject.Create;
      ContentItem.AddPair('type', 'text');
      ContentItem.AddPair('text', ToolResult.ToJSON);
      ContentArr.Add(ContentItem);
      ResultObj.AddPair('content', ContentArr);
      Result := BuildResponse(Id, ResultObj);
    finally
      ToolResult.Free;
    end;
  except
    on E: Exception do
    begin
      ResultObj := TJSONObject.Create;
      ContentArr := TJSONArray.Create;
      ContentItem := TJSONObject.Create;
      ContentItem.AddPair('type', 'text');
      ContentItem.AddPair('text', 'Error: ' + E.Message);
      ContentArr.Add(ContentItem);
      ResultObj.AddPair('content', ContentArr);
      ResultObj.AddPair('isError', TJSONBool.Create(True));
      Result := BuildResponse(Id, ResultObj);
    end;
  end;
end;

function TMCPServer.HandleMessage(const Line: string): string;
var
  JSON, Params: TJSONObject;
  Method: string;
  Id: TJSONValue;
  V: TJSONValue;
begin
  JSON := nil;
  try
    JSON := TJSONObject.ParseJSONValue(Line) as TJSONObject;
  except
    Result := BuildError(nil, ERR_PARSE_ERROR, 'Invalid JSON');
    Exit;
  end;

  if JSON = nil then
  begin
    Result := BuildError(nil, ERR_PARSE_ERROR, 'Invalid JSON');
    Exit;
  end;

  try
    Id := JSON.FindValue('id');

    if not JSON.TryGetValue<string>('method', Method) then
    begin
      if Id <> nil then
        Result := BuildError(Id, ERR_INVALID_REQUEST, 'Missing method')
      else
        Result := '';
      Exit;
    end;

    if JSON.TryGetValue('params', V) and (V is TJSONObject) then
      Params := V as TJSONObject
    else
      Params := nil;

    Log('Received: ' + Method);

    if Method = 'initialize' then
      Result := HandleInitialize(Id, Params)
    else if Method = 'initialized' then
    begin
      Log('Starting eager parse of all project files...');
      FTools.Parser.ParseAllFiles;
      Result := '';
    end
    else if Method = 'tools/list' then
      Result := HandleToolsList(Id)
    else if Method = 'tools/call' then
      Result := HandleToolsCall(Id, Params)
    else if Method = 'notifications/cancelled' then
      Result := ''
    else if Method = 'ping' then
      Result := BuildResponse(Id, TJSONObject.Create)
    else
    begin
      if Id <> nil then
        Result := BuildError(Id, ERR_METHOD_NOT_FOUND, 'Unknown method: ' + Method)
      else
        Result := '';
    end;
  finally
    JSON.Free;
  end;
end;

procedure TMCPServer.OnCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Body, ResponseJSON: string;
  RequestStream: TStream;
  Bytes: TBytes;
begin
  // Only accept POST /mcp
  if (ARequestInfo.CommandType <> hcPOST) or
     (ARequestInfo.Document <> '/mcp') then
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentText := 'Not Found';
    Exit;
  end;

  // Read request body
  RequestStream := ARequestInfo.PostStream;
  if RequestStream <> nil then
  begin
    SetLength(Bytes, RequestStream.Size);
    RequestStream.Position := 0;
    RequestStream.ReadBuffer(Bytes[0], RequestStream.Size);
    Body := TEncoding.UTF8.GetString(Bytes);
  end
  else
    Body := '';

  if Body.Trim = '' then
  begin
    AResponseInfo.ResponseNo := 400;
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.ContentText := BuildError(nil, ERR_PARSE_ERROR, 'Empty request body');
    Exit;
  end;

  try
    ResponseJSON := HandleMessage(Body);
  except
    on E: Exception do
    begin
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ContentType := 'application/json';
      AResponseInfo.ContentText := BuildError(nil, ERR_INTERNAL, E.Message);
      Exit;
    end;
  end;

  // Notifications return empty string — respond with 204
  if ResponseJSON = '' then
  begin
    AResponseInfo.ResponseNo := 204;
    Exit;
  end;

  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := ResponseJSON;
end;

procedure TMCPServer.Run;
begin
  FHTTPServer.Active := True;
  Log('Server listening on http://localhost:' + IntToStr(FPort) + '/mcp');
  Log('Press Enter to stop...');

  ReadLn;

  Log('Server shutting down');
  FHTTPServer.Active := False;
end;

end.
