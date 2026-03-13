unit Tests.DirectTools.GetMethodBody;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetMethodBodyTests = class
  private
    class var FParser: TASTParser;
    class var FTools: TMCPTools;
    class var FProjectPath: string;
    class var FTimeout: Cardinal;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    // get_method_body tests
    [Test] procedure TDog_Speak_Found;
    [Test] procedure TDog_Fetch_Found;
    [Test] procedure TAnimal_Create_Found;
    [Test] procedure TAnimalRegistry_FindAnimal_Found;
    [Test] procedure TAnimalRegistry_RegisterAnimal_Found;
    [Test] procedure TCircle_Area_Found;
    [Test] procedure TShape_Describe_Found;
    [Test] procedure NoFile_SearchesAll;
    [Test] procedure NonExistent_ReturnsError;
    [Test] procedure NonExistent_NoFile_RaisesException;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetMethodBodyTests }

procedure TDirectToolsGetMethodBodyTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  // Wait for background parse to complete
  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetMethodBodyTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetMethodBodyTests.TDog_Speak_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Speak');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('name'), 'Should have name');
      Assert.IsNotNull(Obj.Get('line'), 'Should have line');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TDog_Fetch_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Fetch');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TAnimal_Create_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TAnimal.Create');
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TAnimalRegistry_FindAnimal_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TAnimalRegistry.FindAnimal');
  Params.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TAnimalRegistry_RegisterAnimal_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TAnimalRegistry.RegisterAnimal');
  Params.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TCircle_Area_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TCircle.Area');
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.TShape_Describe_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TShape.Describe');
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.NoFile_SearchesAll;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Speak');
  // No file - should search all parsed files
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('file'), 'Should have file field added');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.NonExistent_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Fly');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetMethodBody(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNotNull(Obj.Get('error'), 'Should have error field');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetMethodBodyTests.NonExistent_NoFile_RaisesException;
var
  Params: TJSONObject;
  Raised: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TFoo.Bar');
  // No file - should search all and raise if not found
  Raised := False;
  try
    FTools.DoGetMethodBody(Params);
  except
    on E: Exception do
    begin
      Raised := True;
      Assert.Contains<string>(E.Message, 'not found', 'Exception should mention not found');
    end;
  end;
  Assert.IsTrue(Raised, 'Should raise exception for non-existent method when no file specified');
  Params.Free;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetMethodBodyTests);
end.
