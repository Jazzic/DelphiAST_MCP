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
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test] procedure AfterSetProject_ListFilesWorks;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows;

{ TDirectSetProjectTests }

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

      // Check that set_project returned files
      Assert.IsNotNull(TJSONObject(SetProjectResult).Get('files'), 'Should have files in result');
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
    // TestProject.dpr references: Animals, Dog, Cat, AnimalRegistry, Shapes (5 .pas + 1 .dpr = 6)
    // test-lib files are NOT included because nothing in test-project references them
    Assert.AreEqual(6, Arr.Count, 'Should have exactly 6 files (TestProject.dpr + 5 .pas)');

    // Check that all project files are present
    var FoundAnimals := False;
    var FoundDog := False;
    var FoundCat := False;
    var FoundShapes := False;
    var FoundAnimalRegistry := False;
    var FoundTestProjectDpr := False;
    for var I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I].Value = 'Animals.pas' then FoundAnimals := True;
      if Arr.Items[I].Value = 'Dog.pas' then FoundDog := True;
      if Arr.Items[I].Value = 'Cat.pas' then FoundCat := True;
      if Arr.Items[I].Value = 'Shapes.pas' then FoundShapes := True;
      if Arr.Items[I].Value = 'AnimalRegistry.pas' then FoundAnimalRegistry := True;
      if Arr.Items[I].Value = 'TestProject.dpr' then FoundTestProjectDpr := True;
    end;
    Assert.IsTrue(FoundAnimals, 'Should contain Animals.pas');
    Assert.IsTrue(FoundDog, 'Should contain Dog.pas');
    Assert.IsTrue(FoundCat, 'Should contain Cat.pas');
    Assert.IsTrue(FoundShapes, 'Should contain Shapes.pas');
    Assert.IsTrue(FoundAnimalRegistry, 'Should contain AnimalRegistry.pas');
    Assert.IsTrue(FoundTestProjectDpr, 'Should contain TestProject.dpr');
  finally
    Result.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectSetProjectTests);
end.
