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

  // Now list_files should work - it returns only files discovered via dependency walk
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
    Assert.IsTrue(Result is TJSONArray, 'Arr is not TJSONArray');
    Arr := Result as TJSONArray;
    // With dependency-driven parsing, list_files returns only files referenced by the DPR
    // TestProject.dpr references: Animals, Dog, Cat, AnimalRegistry, Shapes (5 .pas files + 1 .dpr = 6)
    // test-lib files are NOT included because nothing in test-project references them
    Assert.AreEqual(6, Arr.Count, 'Should have exactly 6 files (TestProject.dpr + 5 .pas)');

    // Verify the test-project files are included
    var FoundAnimals := False;
    var FoundDog := False;
    var FoundCat := False;
    var FoundAnimalRegistry := False;
    var FoundShapes := False;
    var FoundTestProjectDpr := False;
    for var I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I].Value = 'Animals.pas' then FoundAnimals := True;
      if Arr.Items[I].Value = 'Dog.pas' then FoundDog := True;
      if Arr.Items[I].Value = 'Cat.pas' then FoundCat := True;
      if Arr.Items[I].Value = 'AnimalRegistry.pas' then FoundAnimalRegistry := True;
      if Arr.Items[I].Value = 'Shapes.pas' then FoundShapes := True;
      if Arr.Items[I].Value = 'TestProject.dpr' then FoundTestProjectDpr := True;
    end;
    Assert.IsTrue(FoundAnimals, 'Should contain Animals.pas');
    Assert.IsTrue(FoundDog, 'Should contain Dog.pas');
    Assert.IsTrue(FoundCat, 'Should contain Cat.pas');
    Assert.IsTrue(FoundAnimalRegistry, 'Should contain AnimalRegistry.pas');
    Assert.IsTrue(FoundShapes, 'Should contain Shapes.pas');
    Assert.IsTrue(FoundTestProjectDpr, 'Should contain TestProject.dpr');
  finally
    Result.Free;
  end;
end;

end.
