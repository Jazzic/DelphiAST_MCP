unit Tests.SetProject;

interface

uses
  DUnitX.TestFramework, System.JSON, System.SysUtils, System.IOUtils,
  Winapi.Windows, MCP.TestServer;

type
  [TestFixture]
  TSetProjectTests = class
  private
    FServer: TMCPTestServer;
    procedure WaitForReady;
    procedure SetProjectAndWait;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    [Test]
    procedure SetProject_ConfiguresProject;
    [Test]
    procedure AfterSetProject_ListFilesWorks;
    [Test]
    procedure ExcludeFiles_ExcludesFromListFiles;
    [Test]
    procedure ExcludePaths_ExcludesFromListFiles;
    [Test]
    procedure ExcludePaths_ExcludesSubdirectoryFiles;
    [Test]
    procedure ExcludeFiles_WildcardPattern;
    [Test]
    procedure SetProject_ReturnsExcludeFields;
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
      // Check that set_project returned the expected dpr files
      Assert.IsNotNull(SetProjectResult.Get('dprFiles'), 'Should have dprFiles in result');
    finally
      SetProjectResult.Free;
    end;
  finally
    Args.Free;
  end;

  // Wait for parsing to complete
  WaitForReady;

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
    // TestProject.dpr references: Animals, Dog, Cat, AnimalRegistry, Shapes, TestForwardDecl, Generated, GeneratedSub
    // (8 .pas files + 1 .dpr = 9)
    // test-lib files are NOT included because nothing in test-project references them
    Assert.AreEqual(9, Arr.Count, 'Should have exactly 9 files (TestProject.dpr + 8 .pas)');

    // Verify the test-project files are included
    var FoundAnimals := False;
    var FoundDog := False;
    var FoundCat := False;
    var FoundAnimalRegistry := False;
    var FoundShapes := False;
    var FoundTestForwardDecl := False;
    var FoundGenerated := False;
    var FoundGeneratedSub := False;
    var FoundTestProjectDpr := False;
    for var I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I].Value = 'Animals.pas' then FoundAnimals := True;
      if Arr.Items[I].Value = 'Dog.pas' then FoundDog := True;
      if Arr.Items[I].Value = 'Cat.pas' then FoundCat := True;
      if Arr.Items[I].Value = 'AnimalRegistry.pas' then FoundAnimalRegistry := True;
      if Arr.Items[I].Value = 'Shapes.pas' then FoundShapes := True;
      if Arr.Items[I].Value = 'TestForwardDecl.pas' then FoundTestForwardDecl := True;
      if SameText(ExtractFileName(Arr.Items[I].Value), 'Generated.pas') then FoundGenerated := True;
      if SameText(ExtractFileName(Arr.Items[I].Value), 'GeneratedSub.pas') then FoundGeneratedSub := True;
      if Arr.Items[I].Value = 'TestProject.dpr' then FoundTestProjectDpr := True;
    end;
    Assert.IsTrue(FoundAnimals, 'Should contain Animals.pas');
    Assert.IsTrue(FoundDog, 'Should contain Dog.pas');
    Assert.IsTrue(FoundCat, 'Should contain Cat.pas');
    Assert.IsTrue(FoundAnimalRegistry, 'Should contain AnimalRegistry.pas');
    Assert.IsTrue(FoundShapes, 'Should contain Shapes.pas');
    Assert.IsTrue(FoundTestForwardDecl, 'Should contain TestForwardDecl.pas');
    Assert.IsTrue(FoundGenerated, 'Should contain Generated.pas');
    Assert.IsTrue(FoundGeneratedSub, 'Should contain GeneratedSub.pas');
    Assert.IsTrue(FoundTestProjectDpr, 'Should contain TestProject.dpr');
  finally
    Result.Free;
  end;
end;

procedure TSetProjectTests.WaitForReady;
var
  ReadyResult: TJSONValue;
  StartTick: Cardinal;
  Ready: Boolean;
begin
  StartTick := GetTickCount;
  Ready := False;
  repeat
    ReadyResult := TMCPTestHelper.CallTool('is_ready');
    try
      Assert.IsTrue((ReadyResult is TJSONObject), 'ReadyResult is not TJSONObject');
      if TJSONObject(ReadyResult).GetValue<Boolean>('ready', False) then
      begin
        Ready := True;
        Break;
      end;
    finally
      FreeAndNil(ReadyResult);
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;
  Assert.IsTrue(Ready, 'Did not become ready within 15000ms');
end;

procedure TSetProjectTests.SetProjectAndWait;
var
  Args: TJSONObject;
  SetProjectResult: TJSONValue;
begin
  Args := TJSONObject.Create;
  Args.AddPair('path', TMCPTestHelper.GetProjectPath);
  try
    SetProjectResult := TMCPTestHelper.CallTool('set_project', Args);
    SetProjectResult.Free;
  finally
    Args.Free;
  end;
  WaitForReady;
end;

procedure TSetProjectTests.ExcludeFiles_ExcludesFromListFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Args: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundDog: Boolean;
begin
  ConfigFile := TPath.Combine(TMCPTestHelper.GetProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludeFiles":["Dog.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    // Set project with Dog.pas excluded
    Args := TJSONObject.Create;
    Args.AddPair('path', TMCPTestHelper.GetProjectPath);
    try
      SetProjectResult := TMCPTestHelper.CallTool('set_project', Args);
      SetProjectResult.Free;
    finally
      Args.Free;
    end;
    WaitForReady;

    Result := TMCPTestHelper.CallTool('list_files');
    try
      Assert.IsTrue(Result is TJSONArray, 'list_files should return array');
      Arr := Result as TJSONArray;
      // Dog.pas excluded from file index → not reachable via dependency walk
      Assert.AreEqual(8, Arr.Count, 'Should have 8 files (Dog.pas excluded)');
      FoundDog := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(Arr.Items[I].Value, 'Dog.pas') then
          FoundDog := True;
      Assert.IsFalse(FoundDog, 'Dog.pas should be excluded from list_files');
    finally
      Result.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    // Restore original project state
    SetProjectAndWait;
  end;
end;

procedure TSetProjectTests.ExcludePaths_ExcludesFromListFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Args: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundGenerated: Boolean;
begin
  ConfigFile := TPath.Combine(TMCPTestHelper.GetProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    // Set project with Generated/ directory excluded
    Args := TJSONObject.Create;
    Args.AddPair('path', TMCPTestHelper.GetProjectPath);
    try
      SetProjectResult := TMCPTestHelper.CallTool('set_project', Args);
      SetProjectResult.Free;
    finally
      Args.Free;
    end;
    WaitForReady;

    Result := TMCPTestHelper.CallTool('list_files');
    try
      Assert.IsTrue(Result is TJSONArray, 'list_files should return array');
      Arr := Result as TJSONArray;
      // Generated/ directory excluded → Generated.pas not in file index → not reachable
      Assert.AreEqual(7, Arr.Count, 'Should have 7 files (Generated.pas excluded)');
      FoundGenerated := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(ExtractFileName(Arr.Items[I].Value), 'Generated.pas') then
          FoundGenerated := True;
      Assert.IsFalse(FoundGenerated, 'Generated.pas should be excluded from list_files');
    finally
      Result.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    SetProjectAndWait;
  end;
end;

procedure TSetProjectTests.ExcludePaths_ExcludesSubdirectoryFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Args: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundGeneratedSub: Boolean;
begin
  ConfigFile := TPath.Combine(TMCPTestHelper.GetProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    // Set project with Generated/ directory excluded
    Args := TJSONObject.Create;
    Args.AddPair('path', TMCPTestHelper.GetProjectPath);
    try
      SetProjectResult := TMCPTestHelper.CallTool('set_project', Args);
      SetProjectResult.Free;
    finally
      Args.Free;
    end;
    WaitForReady;

    Result := TMCPTestHelper.CallTool('list_files');
    try
      Assert.IsTrue(Result is TJSONArray, 'list_files should return array');
      Arr := Result as TJSONArray;
      // Generated/ directory excluded → Generated.pas (in Generated/) and
      // GeneratedSub.pas (in Generated/SubDir/) must both be excluded
      Assert.AreEqual(7, Arr.Count, 'Should have 7 files (Generated.pas and GeneratedSub.pas both excluded)');
      FoundGeneratedSub := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(ExtractFileName(Arr.Items[I].Value), 'GeneratedSub.pas') then
          FoundGeneratedSub := True;
      Assert.IsFalse(FoundGeneratedSub, 'GeneratedSub.pas (in Generated/SubDir/) should be excluded when Generated/ is excluded');
    finally
      Result.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    SetProjectAndWait;
  end;
end;

procedure TSetProjectTests.ExcludeFiles_WildcardPattern;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Args: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundDog: Boolean;
begin
  ConfigFile := TPath.Combine(TMCPTestHelper.GetProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  // Wildcard pattern D*.pas should match Dog.pas
  TestConfig := '{"libraryPaths":["../test-lib"],"excludeFiles":["D*.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Args := TJSONObject.Create;
    Args.AddPair('path', TMCPTestHelper.GetProjectPath);
    try
      SetProjectResult := TMCPTestHelper.CallTool('set_project', Args);
      SetProjectResult.Free;
    finally
      Args.Free;
    end;
    WaitForReady;

    Result := TMCPTestHelper.CallTool('list_files');
    try
      Assert.IsTrue(Result is TJSONArray, 'list_files should return array');
      Arr := Result as TJSONArray;
      // D*.pas matches Dog.pas → excluded from file index
      Assert.AreEqual(8, Arr.Count, 'Should have 8 files (Dog.pas excluded via wildcard)');
      FoundDog := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(Arr.Items[I].Value, 'Dog.pas') then
          FoundDog := True;
      Assert.IsFalse(FoundDog, 'Dog.pas should be excluded by wildcard D*.pas');
    finally
      Result.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    SetProjectAndWait;
  end;
end;

procedure TSetProjectTests.SetProject_ReturnsExcludeFields;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Args: TJSONObject;
  SetProjectResult: TJSONObject;
  ExcludePathsVal, ExcludeFilesVal: TJSONValue;
begin
  ConfigFile := TPath.Combine(TMCPTestHelper.GetProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"],"excludeFiles":["*.generated.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);
    Args := TJSONObject.Create;
    Args.AddPair('path', TMCPTestHelper.GetProjectPath);
    try
      SetProjectResult := TMCPTestHelper.CallTool('set_project', Args) as TJSONObject;
      try
        Assert.IsNotNull(SetProjectResult, 'set_project result is nil');
        ExcludePathsVal := SetProjectResult.GetValue('excludePaths');
        Assert.IsNotNull(ExcludePathsVal, 'Response should contain excludePaths');
        Assert.IsTrue(ExcludePathsVal is TJSONArray, 'excludePaths should be array');
        Assert.AreEqual(1, TJSONArray(ExcludePathsVal).Count, 'excludePaths should have 1 entry');
        Assert.AreEqual('Generated', TJSONArray(ExcludePathsVal).Items[0].Value);
        ExcludeFilesVal := SetProjectResult.GetValue('excludeFiles');
        Assert.IsNotNull(ExcludeFilesVal, 'Response should contain excludeFiles');
        Assert.IsTrue(ExcludeFilesVal is TJSONArray, 'excludeFiles should be array');
        Assert.AreEqual(1, TJSONArray(ExcludeFilesVal).Count, 'excludeFiles should have 1 entry');
        Assert.AreEqual('*.generated.pas', TJSONArray(ExcludeFilesVal).Items[0].Value);
      finally
        SetProjectResult.Free;
      end;
    finally
      Args.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    SetProjectAndWait;
  end;
end;

end.
