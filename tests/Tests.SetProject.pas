unit Tests.SetProject;

interface

uses
  DUnitX.TestFramework, System.JSON, System.SysUtils, Winapi.Windows, MCP.TestServer;

type
  [TestFixture]
  TSetProjectTests = class
  private
    FServer: TMCPTestServer;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    [Test]
    procedure SetProject_ConfiguresProject;
    [Test]
    procedure AfterSetProject_ListFilesWorks;
  end;

implementation

uses
  MCP.TestHelper;

procedure TSetProjectTests.Setup;
var
  ProjectPath: string;
begin
  // Start server WITHOUT project path - it will be configured via set_project
  ProjectPath := TMCPTestHelper.GetProjectPath;
  FServer := TMCPTestServer.Create('', 3098); // Different port to avoid conflict
  FServer.Start;
  // Use this server instance for subsequent calls
  TMCPTestHelper.SetServer(FServer);
end;

procedure TSetProjectTests.Teardown;
begin
  // Restore the original server instance
  TMCPTestHelper.SetServer(TMCPTestServer.Instance);
  FServer.Free;
end;

procedure TSetProjectTests.SetProject_ConfiguresProject;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  ProjectPath: string;
begin
  ProjectPath := TMCPTestHelper.GetProjectPath;
  Args := TJSONObject.Create;
  Args.AddPair('path', ProjectPath);
  try
    Result := TMCPTestHelper.CallTool('set_project', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Obj := Result as TJSONObject;
      Assert.IsNotNull(Obj, 'Result is not an object');
      // Should return project info with 5 files
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'files');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TSetProjectTests.AfterSetProject_ListFilesWorks;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  SetProjectResult: TJSONObject;
begin
  // First configure the project
  Args := TJSONObject.Create;
  Args.AddPair('path', TMCPTestHelper.GetProjectPath);
  try
    SetProjectResult := TMCPTestHelper.CallTool('set_project', Args) as TJSONObject;
    try
      // Check that set_project returned the expected file count
      Assert.IsNotNull(SetProjectResult.Get('files'), 'Should have files in result');
    finally
      SetProjectResult.Free;
    end;
  finally
    Args.Free;
  end;

  // Wait for parsing to complete
  var ReadyResult: TJSONValue;
  var StartTick := GetTickCount;
  var Ready := false;
  repeat
    ReadyResult := TMCPTestHelper.CallTool('is_ready');
    try
      Assert.IsTrue((ReadyResult is TJSONObject), 'ReadyResult is not TJSONObject');
      if TJSONObject(ReadyResult).GetValue<Boolean>('ready', False) then
      begin
        Ready:= true;
        Break;
      end;
    finally
      FreeAndNil(ReadyResult);
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;

  Assert.IsTrue(Ready, 'Did not become ready within 15000ms' );

  // Now list_files should work
  Result := TMCPTestHelper.CallTool('list_files');
  try
    // If result is an error object, fail with specific message
    if Result is TJSONObject then
    begin
      var ErrObj := TJSONObject(Result);
      if ErrObj.Get('error') <> nil then
        Assert.Fail('list_files returned error: ' + ErrObj.GetValue<string>('error', ''));
    end;

    Assert.IsNotNull(Result, 'Result is nil');
    Arr := Result as TJSONArray;
    Assert.IsNotNull(Arr, 'Result is not an array');
    Assert.AreEqual(5, Arr.Count, 'Should have 5 files');
  finally
    Result.Free;
  end;
end;

end.
