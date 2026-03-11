unit MCP.TestHelper;

interface

uses
  System.SysUtils, System.JSON, MCP.TestServer;

type
  TMCPTestHelper = class
  private
    class var FServer: TMCPTestServer;
  public
    class procedure SetServer(AServer: TMCPTestServer);
    class function GetServer: TMCPTestServer;
    class function CallTool(const ToolName: string): TJSONValue; overload;
    class function CallTool(const ToolName: string; const Args: TJSONObject): TJSONValue; overload;
    class function CallTool(const ToolName: string; const Args: TJSONObject;
      ExpectError: Boolean): TJSONValue; overload;
    class procedure AssertArrayContains(Arr: TJSONArray; const Substr: string);
    class procedure AssertArrayLength(Arr: TJSONArray; Expected: Integer);
    class procedure AssertStringContains(const Str, Substr: string);
    class function GetProjectPath: string;
  end;

implementation

class procedure TMCPTestHelper.SetServer(AServer: TMCPTestServer);
begin
  FServer := AServer;
end;

class function TMCPTestHelper.GetServer: TMCPTestServer;
begin
  Result := FServer;
end;

class function TMCPTestHelper.CallTool(const ToolName: string): TJSONValue;
begin
  if not Assigned(FServer) then
    raise Exception.Create('Test server not initialized');
  Result := FServer.CallTool(ToolName);
end;

class function TMCPTestHelper.CallTool(const ToolName: string; const Args: TJSONObject): TJSONValue;
begin
  if not Assigned(FServer) then
    raise Exception.Create('Test server not initialized');
  Result := FServer.CallTool(ToolName, Args, False);
end;

class function TMCPTestHelper.CallTool(const ToolName: string; const Args: TJSONObject;
  ExpectError: Boolean): TJSONValue;
begin
  if not Assigned(FServer) then
    raise Exception.Create('Test server not initialized');
  Result := FServer.CallTool(ToolName, Args, ExpectError);
end;

class procedure TMCPTestHelper.AssertArrayContains(Arr: TJSONArray; const Substr: string);
var
  I: Integer;
  Item: TJSONValue;
begin
  if not Assigned(Arr) then
    raise Exception.Create('Array is nil');
  for I := 0 to Arr.Count - 1 do
  begin
    Item := Arr[I];
    if Assigned(Item) and (Pos(Substr, Item.ToString) > 0) then
      Exit;
  end;
  raise Exception.Create(Format('Array does not contain "%s". Contents: %s', [Substr, Arr.ToString]));
end;

class procedure TMCPTestHelper.AssertArrayLength(Arr: TJSONArray; Expected: Integer);
begin
  if not Assigned(Arr) then
    raise Exception.Create('Array is nil');
  if Arr.Count <> Expected then
    raise Exception.Create(Format('Expected %d items but got %d: %s',
      [Expected, Arr.Count, Arr.ToString]));
end;

class procedure TMCPTestHelper.AssertStringContains(const Str, Substr: string);
begin
  if Pos(Substr, Str) = 0 then
    raise Exception.Create(Format('String does not contain "%s". String: %s',
      [Substr, Str]));
end;

class function TMCPTestHelper.GetProjectPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..\tests\test-project';
end;

end.
