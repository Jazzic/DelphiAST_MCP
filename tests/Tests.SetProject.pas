unit Tests.SetProject;

interface

uses
  DUnitX.TestFramework, System.JSON, MCP.TestServer;

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
begin
  // First configure the project
  Args := TJSONObject.Create;
  Args.AddPair('path', TMCPTestHelper.GetProjectPath);
  try
    TMCPTestHelper.CallTool('set_project', Args);
  finally
    Args.Free;
  end;

  // Now list_files should work
  Result := TMCPTestHelper.CallTool('list_files');
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Arr := Result as TJSONArray;
    Assert.IsNotNull(Arr, 'Result is not an array');
    Assert.AreEqual(5, Arr.Count, 'Should have 5 files');
  finally
    Result.Free;
  end;
end;

end.
