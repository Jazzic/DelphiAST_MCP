unit Tests.DirectTools.SetProject;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectSetProjectTests = class
  private
    FParser: TASTParser;
    FTools: TMCPTools;
    FProjectPath: string;
    procedure WaitForReady;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test] procedure AfterSetProject_ListFilesWorks;
    [Test] procedure SetProject_CalledTwice_DoesNotCrash;
    [Test] procedure SetProject_CalledTwiceRapidly_DoesNotCrash;
    [Test] procedure ExcludeFiles_ExcludesFromListFiles;
    [Test] procedure ExcludePaths_ExcludesFromListFiles;
    [Test] procedure ExcludePaths_ExcludesSubdirectoryFiles;
    [Test] procedure ExcludeFiles_WildcardPattern;
    [Test] procedure SetProject_ReturnsExcludeFields;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows;

{ TDirectSetProjectTests }

procedure TDirectSetProjectTests.WaitForReady;
var
  StartTick: Cardinal;
begin
  StartTick := GetTickCount;
  repeat
    if FParser.IsReady then
      Exit;
    Sleep(200);
  until GetTickCount - StartTick > 15000;
  Assert.Fail('Did not become ready within 15000ms');
end;

procedure TDirectSetProjectTests.SetupFixture;
begin
  // Create parser WITHOUT a pre-configured project
  // This allows us to test set_project configuring it from scratch
  FParser := TASTParser.Create('');
  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectSetProjectTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectSetProjectTests.AfterSetProject_ListFilesWorks;
var
  Params: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  StartTick: Cardinal;
  Ready: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');

  // First configure the project via set_project
  Params := TJSONObject.Create;
  Params.AddPair('path', FProjectPath);
  try
    SetProjectResult := FTools.DoSetProject(Params);
    try
      // Check that set_project returned the expected structure
      Assert.IsNotNull(SetProjectResult, 'SetProject result should not be null');
      Assert.IsTrue(SetProjectResult is TJSONObject, 'SetProject result should be TJSONObject');
      Assert.IsNull(TJSONObject(SetProjectResult).Get('error'), 'SetProject should not return an error');

      // Check that set_project returned dprFiles
      Assert.IsNotNull(TJSONObject(SetProjectResult).Get('dprFiles'), 'Should have dprFiles in result');
    finally
      SetProjectResult.Free;
    end;
  finally
    Params.Free;
  end;

  // Wait for parsing to complete via IsReady
  StartTick := GetTickCount;
  Ready := False;
  repeat
    if FParser.IsReady then
    begin
      Ready := True;
      Break;
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;

  Assert.IsTrue(Ready, 'Did not become ready within 15000ms');

  // Now list_files should work - it returns only files discovered via dependency walk
  Result := FTools.DoListFiles(TJSONObject.Create);
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Assert.IsTrue(Result is TJSONArray, 'Result is not TJSONArray');
    Arr := TJSONArray(Result);

    // With dependency-driven parsing, list_files returns only files referenced by the DPR
    // TestProject.dpr references: Animals, Dog, Cat, AnimalRegistry, Shapes, TestForwardDecl, Generated, GeneratedSub
    // (8 .pas + 1 .dpr = 9)
    // test-lib files are NOT included because nothing in test-project references them
    Assert.AreEqual(9, Arr.Count, 'Should have exactly 9 files (TestProject.dpr + 8 .pas)');

    // Check that all project files are present
    var FoundAnimals := False;
    var FoundDog := False;
    var FoundCat := False;
    var FoundShapes := False;
    var FoundAnimalRegistry := False;
    var FoundTestForwardDecl := False;
    var FoundGenerated := False;
    var FoundGeneratedSub := False;
    var FoundTestProjectDpr := False;
    for var I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I].Value = 'Animals.pas' then FoundAnimals := True;
      if Arr.Items[I].Value = 'Dog.pas' then FoundDog := True;
      if Arr.Items[I].Value = 'Cat.pas' then FoundCat := True;
      if Arr.Items[I].Value = 'Shapes.pas' then FoundShapes := True;
      if Arr.Items[I].Value = 'AnimalRegistry.pas' then FoundAnimalRegistry := True;
      if Arr.Items[I].Value = 'TestForwardDecl.pas' then FoundTestForwardDecl := True;
      if SameText(ExtractFileName(Arr.Items[I].Value), 'Generated.pas') then FoundGenerated := True;
      if SameText(ExtractFileName(Arr.Items[I].Value), 'GeneratedSub.pas') then FoundGeneratedSub := True;
      if Arr.Items[I].Value = 'TestProject.dpr' then FoundTestProjectDpr := True;
    end;
    Assert.IsTrue(FoundAnimals, 'Should contain Animals.pas');
    Assert.IsTrue(FoundDog, 'Should contain Dog.pas');
    Assert.IsTrue(FoundCat, 'Should contain Cat.pas');
    Assert.IsTrue(FoundShapes, 'Should contain Shapes.pas');
    Assert.IsTrue(FoundAnimalRegistry, 'Should contain AnimalRegistry.pas');
    Assert.IsTrue(FoundTestForwardDecl, 'Should contain TestForwardDecl.pas');
    Assert.IsTrue(FoundGenerated, 'Should contain Generated.pas');
    Assert.IsTrue(FoundGeneratedSub, 'Should contain GeneratedSub.pas');
    Assert.IsTrue(FoundTestProjectDpr, 'Should contain TestProject.dpr');
  finally
    Result.Free;
  end;
end;

procedure TDirectSetProjectTests.SetProject_CalledTwice_DoesNotCrash;
var
  Params: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  StartTick: Cardinal;
  Ready: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');

  // First set_project call
  Params := TJSONObject.Create;
  Params.AddPair('path', FProjectPath);
  try
    SetProjectResult := FTools.DoSetProject(Params);
    try
      Assert.IsNotNull(SetProjectResult, 'First SetProject result should not be null');
    finally
      SetProjectResult.Free;
    end;
  finally
    Params.Free;
  end;

  // Wait for ready
  StartTick := GetTickCount;
  Ready := False;
  repeat
    if FParser.IsReady then
    begin
      Ready := True;
      Break;
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;
  Assert.IsTrue(Ready, 'Did not become ready after first set_project within 15000ms');

  // Second set_project call - should NOT crash
  Params := TJSONObject.Create;
  Params.AddPair('path', FProjectPath);
  try
    SetProjectResult := FTools.DoSetProject(Params);
    try
      Assert.IsNotNull(SetProjectResult, 'Second SetProject result should not be null');
    finally
      SetProjectResult.Free;
    end;
  finally
    Params.Free;
  end;

  // Wait for ready again
  StartTick := GetTickCount;
  Ready := False;
  repeat
    if FParser.IsReady then
    begin
      Ready := True;
      Break;
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;
  Assert.IsTrue(Ready, 'Did not become ready after second set_project within 15000ms');

  // Verify ListFiles returns 7 files
  Result := FTools.DoListFiles(TJSONObject.Create);
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Assert.IsTrue(Result is TJSONArray, 'Result is not TJSONArray');
    Arr := TJSONArray(Result);
    Assert.AreEqual(9, Arr.Count, 'Should have exactly 9 files after second set_project');
  finally
    Result.Free;
  end;
end;

procedure TDirectSetProjectTests.SetProject_CalledTwiceRapidly_DoesNotCrash;
var
  Params: TJSONObject;
  SetProjectResult: TJSONValue;
  Result: TJSONValue;
  Arr: TJSONArray;
  StartTick: Cardinal;
  Ready: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');

  // First set_project call
  Params := TJSONObject.Create;
  Params.AddPair('path', FProjectPath);
  try
    SetProjectResult := FTools.DoSetProject(Params);
    try
      Assert.IsNotNull(SetProjectResult, 'First SetProject result should not be null');
    finally
      SetProjectResult.Free;
    end;
  finally
    Params.Free;
  end;

  // Immediately call set_project again without waiting - should NOT crash
  Params := TJSONObject.Create;
  Params.AddPair('path', FProjectPath);
  try
    SetProjectResult := FTools.DoSetProject(Params);
    try
      Assert.IsNotNull(SetProjectResult, 'Second SetProject result should not be null');
    finally
      SetProjectResult.Free;
    end;
  finally
    Params.Free;
  end;

  // Now wait for ready
  StartTick := GetTickCount;
  Ready := False;
  repeat
    if FParser.IsReady then
    begin
      Ready := True;
      Break;
    end;
    Sleep(200);
  until GetTickCount - StartTick > 15000;
  Assert.IsTrue(Ready, 'Did not become ready within 15000ms');

  // Verify ListFiles returns 7 files
  Result := FTools.DoListFiles(TJSONObject.Create);
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Assert.IsTrue(Result is TJSONArray, 'Result is not TJSONArray');
    Arr := TJSONArray(Result);
    Assert.AreEqual(9, Arr.Count, 'Should have exactly 9 files after rapid double set_project');
  finally
    Result.Free;
  end;
end;

procedure TDirectSetProjectTests.ExcludeFiles_ExcludesFromListFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Params: TJSONObject;
  SetProjectResult, ListResult: TJSONValue;
  Arr: TJSONArray;
  FoundDog: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  ConfigFile := TPath.Combine(FProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludeFiles":["Dog.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;

    WaitForReady;

    ListResult := FTools.DoListFiles(TJSONObject.Create);
    try
      Assert.IsTrue(ListResult is TJSONArray, 'list_files should return array');
      Arr := TJSONArray(ListResult);
      Assert.AreEqual(8, Arr.Count, 'Should have 8 files (Dog.pas excluded)');
      FoundDog := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(Arr.Items[I].Value, 'Dog.pas') then
          FoundDog := True;
      Assert.IsFalse(FoundDog, 'Dog.pas should be excluded from list_files');
    finally
      ListResult.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    // Restore original project state
    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;
    WaitForReady;
  end;
end;

procedure TDirectSetProjectTests.ExcludePaths_ExcludesFromListFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Params: TJSONObject;
  SetProjectResult, ListResult: TJSONValue;
  Arr: TJSONArray;
  FoundGenerated: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  ConfigFile := TPath.Combine(FProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;

    WaitForReady;

    ListResult := FTools.DoListFiles(TJSONObject.Create);
    try
      Assert.IsTrue(ListResult is TJSONArray, 'list_files should return array');
      Arr := TJSONArray(ListResult);
      // Generated/ directory excluded → Generated.pas not in file index → not reachable
      Assert.AreEqual(7, Arr.Count, 'Should have 7 files (Generated.pas excluded)');
      FoundGenerated := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(ExtractFileName(Arr.Items[I].Value), 'Generated.pas') then
          FoundGenerated := True;
      Assert.IsFalse(FoundGenerated, 'Generated.pas should be excluded from list_files');
    finally
      ListResult.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;
    WaitForReady;
  end;
end;

procedure TDirectSetProjectTests.ExcludePaths_ExcludesSubdirectoryFiles;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Params: TJSONObject;
  SetProjectResult, ListResult: TJSONValue;
  Arr: TJSONArray;
  FoundGeneratedSub: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  ConfigFile := TPath.Combine(FProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;

    WaitForReady;

    ListResult := FTools.DoListFiles(TJSONObject.Create);
    try
      Assert.IsTrue(ListResult is TJSONArray, 'list_files should return array');
      Arr := TJSONArray(ListResult);
      // Generated/ directory excluded → Generated.pas (in Generated/) and
      // GeneratedSub.pas (in Generated/SubDir/) must both be excluded
      Assert.AreEqual(7, Arr.Count, 'Should have 7 files (Generated.pas and GeneratedSub.pas both excluded)');
      FoundGeneratedSub := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(ExtractFileName(Arr.Items[I].Value), 'GeneratedSub.pas') then
          FoundGeneratedSub := True;
      Assert.IsFalse(FoundGeneratedSub, 'GeneratedSub.pas (in Generated/SubDir/) should be excluded when Generated/ is excluded');
    finally
      ListResult.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;
    WaitForReady;
  end;
end;

procedure TDirectSetProjectTests.ExcludeFiles_WildcardPattern;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Params: TJSONObject;
  SetProjectResult, ListResult: TJSONValue;
  Arr: TJSONArray;
  FoundDog: Boolean;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  ConfigFile := TPath.Combine(FProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  // Wildcard pattern D*.pas should match Dog.pas
  TestConfig := '{"libraryPaths":["../test-lib"],"excludeFiles":["D*.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;

    WaitForReady;

    ListResult := FTools.DoListFiles(TJSONObject.Create);
    try
      Assert.IsTrue(ListResult is TJSONArray, 'list_files should return array');
      Arr := TJSONArray(ListResult);
      // D*.pas matches Dog.pas → excluded from file index
      Assert.AreEqual(8, Arr.Count, 'Should have 8 files (Dog.pas excluded via wildcard)');
      FoundDog := False;
      for var I := 0 to Arr.Count - 1 do
        if SameText(Arr.Items[I].Value, 'Dog.pas') then
          FoundDog := True;
      Assert.IsFalse(FoundDog, 'Dog.pas should be excluded by wildcard D*.pas');
    finally
      ListResult.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;
    WaitForReady;
  end;
end;

procedure TDirectSetProjectTests.SetProject_ReturnsExcludeFields;
var
  ConfigFile, OriginalConfig, TestConfig: string;
  Params: TJSONObject;
  SetProjectResult: TJSONValue;
  Obj: TJSONObject;
  ExcludePathsVal, ExcludeFilesVal: TJSONValue;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  ConfigFile := TPath.Combine(FProjectPath, '.delphi-ast.json');
  OriginalConfig := TFile.ReadAllText(ConfigFile);
  TestConfig := '{"libraryPaths":["../test-lib"],"excludePaths":["Generated"],"excludeFiles":["*.generated.pas"]}';
  try
    TFile.WriteAllText(ConfigFile, TestConfig);

    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      try
        Assert.IsTrue(SetProjectResult is TJSONObject, 'Result should be TJSONObject');
        Obj := TJSONObject(SetProjectResult);
        ExcludePathsVal := Obj.GetValue('excludePaths');
        Assert.IsNotNull(ExcludePathsVal, 'Response should contain excludePaths');
        Assert.IsTrue(ExcludePathsVal is TJSONArray, 'excludePaths should be array');
        Assert.AreEqual(1, TJSONArray(ExcludePathsVal).Count, 'excludePaths should have 1 entry');
        Assert.AreEqual('Generated', TJSONArray(ExcludePathsVal).Items[0].Value);
        ExcludeFilesVal := Obj.GetValue('excludeFiles');
        Assert.IsNotNull(ExcludeFilesVal, 'Response should contain excludeFiles');
        Assert.IsTrue(ExcludeFilesVal is TJSONArray, 'excludeFiles should be array');
        Assert.AreEqual(1, TJSONArray(ExcludeFilesVal).Count, 'excludeFiles should have 1 entry');
        Assert.AreEqual('*.generated.pas', TJSONArray(ExcludeFilesVal).Items[0].Value);
      finally
        SetProjectResult.Free;
      end;
    finally
      Params.Free;
    end;
  finally
    TFile.WriteAllText(ConfigFile, OriginalConfig);
    Params := TJSONObject.Create;
    Params.AddPair('path', FProjectPath);
    try
      SetProjectResult := FTools.DoSetProject(Params);
      SetProjectResult.Free;
    finally
      Params.Free;
    end;
    WaitForReady;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectSetProjectTests);
end.
