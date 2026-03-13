unit Tests.DirectTools.ParseUnit;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsParseUnitTests = class
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

    // parse_unit tests
    [Test] procedure NoFile_ReturnsAllUnits;
    [Test] procedure Animals_HasInterfaceAndClass;
    [Test] procedure Dog_HasOneClass;
    [Test] procedure AnimalRegistry_HasUsesClauses;
    [Test] procedure Shapes_HasThreeTypes;
    [Test] procedure AllUnits_TypeCounts;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

function ArrayContainsValue(Arr: TJSONArray; const Value: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Arr.Count - 1 do
  begin
    if Arr.Items[I].Value = Value then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function StringListContains(const Arr: TArray<string>; const Value: string): Boolean;
var
  S: string;
begin
  Result := False;
  for S in Arr do
  begin
    if S = Value then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ TDirectToolsParseUnitTests }

procedure TDirectToolsParseUnitTests.SetupFixture;
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

procedure TDirectToolsParseUnitTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsParseUnitTests.NoFile_ReturnsAllUnits;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray when no file specified');
      Arr := TJSONArray(Result);
      Assert.AreEqual(5, Arr.Count, 'Should have 5 units');

      // Check each unit has expected fields
      for I := 0 to Arr.Count - 1 do
      begin
        Obj := Arr.Items[I] as TJSONObject;
        Assert.IsNotNull(Obj.Get('file'), 'Should have file field');
        Assert.IsNotNull(Obj.Get('name'), 'Should have name field');
        Assert.IsNotNull(Obj.Get('types'), 'Should have types field');
        Assert.IsNotNull(Obj.Get('routines'), 'Should have routines field');
      end;
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsParseUnitTests.Animals_HasInterfaceAndClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Types: TJSONArray;
  I: Integer;
  TypeObj: TJSONObject;
  FoundNames: TArray<string>;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual('Animals', Obj.GetValue<string>('name'), 'Unit name should be Animals');

      // Check types - should have TAnimalKind (enum), IAnimal (interface), TAnimal (class)
      Types := Obj.GetValue<TJSONArray>('types');
      Assert.IsNotNull(Types, 'Should have types array');
      Assert.IsTrue(Types.Count >= 3, 'Should have at least 3 types');

      SetLength(FoundNames, 0);
      for I := 0 to Types.Count - 1 do
      begin
        TypeObj := Types.Items[I] as TJSONObject;
        FoundNames := FoundNames + [TypeObj.GetValue<string>('name')];
      end;

      Assert.IsTrue(StringListContains(FoundNames, 'TAnimalKind'), 'Should contain TAnimalKind');
      Assert.IsTrue(StringListContains(FoundNames, 'IAnimal'), 'Should contain IAnimal');
      Assert.IsTrue(StringListContains(FoundNames, 'TAnimal'), 'Should contain TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsParseUnitTests.Dog_HasOneClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  UsesInt: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual('Dog', Obj.GetValue<string>('name'), 'Unit name should be Dog');

      // Check uses_interface contains Animals
      UsesInt := Obj.GetValue<TJSONArray>('uses_interface');
      Assert.IsNotNull(UsesInt, 'Should have uses_interface');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Animals'), 'Uses clause should contain Animals');

      // Should have TDog type
      Assert.IsNotNull(Obj.Get('types'), 'Should have types');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsParseUnitTests.AnimalRegistry_HasUsesClauses;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  UsesInt: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual('AnimalRegistry', Obj.GetValue<string>('name'), 'Unit name should be AnimalRegistry');

      // Check uses_interface contains Animals, Dog, Cat
      UsesInt := Obj.GetValue<TJSONArray>('uses_interface');
      Assert.IsNotNull(UsesInt, 'Should have uses_interface');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Animals'), 'Uses clause should contain Animals');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Dog'), 'Uses clause should contain Dog');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Cat'), 'Uses clause should contain Cat');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsParseUnitTests.Shapes_HasThreeTypes;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Types: TJSONArray;
  I: Integer;
  TypeObj: TJSONObject;
  FoundNames: TArray<string>;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual('Shapes', Obj.GetValue<string>('name'), 'Unit name should be Shapes');

      // Check types - should have TShape, TCircle, TRectangle
      Types := Obj.GetValue<TJSONArray>('types');
      Assert.IsNotNull(Types, 'Should have types array');
      Assert.AreEqual(3, Types.Count, 'Should have 3 types');

      SetLength(FoundNames, 0);
      for I := 0 to Types.Count - 1 do
      begin
        TypeObj := Types.Items[I] as TJSONObject;
        FoundNames := FoundNames + [TypeObj.GetValue<string>('name')];
      end;

      Assert.IsTrue(StringListContains(FoundNames, 'TShape'), 'Should contain TShape');
      Assert.IsTrue(StringListContains(FoundNames, 'TCircle'), 'Should contain TCircle');
      Assert.IsTrue(StringListContains(FoundNames, 'TRectangle'), 'Should contain TRectangle');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsParseUnitTests.AllUnits_TypeCounts;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoParseUnit(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(5, Arr.Count, 'Should have 5 units');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsParseUnitTests);
end.
