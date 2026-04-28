unit Tests.DirectTools.AnalyzeCoupling;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsAnalyzeCouplingTests = class
  private
    class var FParser: TASTParser;
    class var FTools: TMCPTools;
    class var FProjectPath: string;

    function CallCoupling(const FileName: string): TJSONObject;
    function FindUsage(Arr: TJSONArray; const Symbol, Kind: string): TJSONObject;
    function FindUsageWithMethod(Arr: TJSONArray; const Symbol, Kind, MethodFragment: string): TJSONObject;
    function GetUsagesArr(Obj: TJSONObject): TJSONArray;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    // AnimalRegistry tests
    [Test] procedure AnimalRegistry_ResultHasRequiredKeys;
    [Test] procedure AnimalRegistry_UnitNameCorrect;
    [Test] procedure AnimalRegistry_IAnimalFromAnimals;
    [Test] procedure AnimalRegistry_FieldTypeDetected;
    [Test] procedure AnimalRegistry_InterfaceParamTypeDetected;
    [Test] procedure AnimalRegistry_ImplParamTypeDetected;
    [Test] procedure AnimalRegistry_InterfaceReturnTypeDetected;
    [Test] procedure AnimalRegistry_ImplReturnTypeDetected;
    [Test] procedure AnimalRegistry_ByUnitHasAnimalsKey;
    [Test] procedure AnimalRegistry_ByUnitAnimalsSymbolsHasIAnimal;
    [Test] procedure AnimalRegistry_TotalUsagesPositive;
    [Test] procedure AnimalRegistry_FieldTypeOnCorrectLine;
    [Test] procedure AnimalRegistry_NoSelfReferences;

    // Dog tests
    [Test] procedure Dog_InheritanceCouplingFound;
    [Test] procedure Dog_ByUnitHasAnimals;
    [Test] procedure Dog_TotalUsagesPositive;
    [Test] procedure Dog_NoSelfReference;

    // Cat tests
    [Test] procedure Cat_InheritanceCouplingFound;
    [Test] procedure Cat_ByUnitHasAnimals;

    // CouplingDemo tests
    [Test] procedure CouplingDemo_FieldTypeForTDog;
    [Test] procedure CouplingDemo_ParamTypeForIAnimal;
    [Test] procedure CouplingDemo_ReturnTypeForTDog;
    [Test] procedure CouplingDemo_LocalVarTAnimalKind;
    [Test] procedure CouplingDemo_LocalVarTDog;
    [Test] procedure CouplingDemo_QualifiedCallTDog;
    [Test] procedure CouplingDemo_ByUnitHasDog;
    [Test] procedure CouplingDemo_ByUnitHasAnimals;
    [Test] procedure CouplingDemo_TwoSourceUnits;
    [Test] procedure CouplingDemo_NoSelfReferences;

    // Shapes (negative)
    [Test] procedure Shapes_TotalUsagesIsZero;
    [Test] procedure Shapes_UsagesArrayEmpty;

    // ProceduralUnit tests — standalone procedure enclosing_method
    [Test] procedure ProceduralUnit_ParamTypeHasEnclosingMethod;
    [Test] procedure ProceduralUnit_ReturnTypeHasEnclosingMethod;
    [Test] procedure ProceduralUnit_LocalVarHasEnclosingMethod;
    [Test] procedure ProceduralUnit_EnclosingTypeIsAlwaysEmpty;

    // Error cases
    [Test] procedure MissingFileParam_ReturnsError;
    [Test] procedure NonExistentFile_ReturnsError;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ Helpers }

function TDirectToolsAnalyzeCouplingTests.CallCoupling(const FileName: string): TJSONObject;
var
  Params: TJSONObject;
  Raw: TJSONValue;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', FileName);
  try
    Raw := FTools.DoAnalyzeCoupling(Params);
    Assert.IsTrue(Raw is TJSONObject, 'Result must be TJSONObject');
    Result := TJSONObject(Raw);
  finally
    Params.Free;
  end;
end;

function TDirectToolsAnalyzeCouplingTests.GetUsagesArr(Obj: TJSONObject): TJSONArray;
var
  V: TJSONValue;
begin
  Result := nil;
  if Obj.TryGetValue('usages', V) and (V is TJSONArray) then
    Result := TJSONArray(V);
end;

function TDirectToolsAnalyzeCouplingTests.FindUsage(Arr: TJSONArray;
  const Symbol, Kind: string): TJSONObject;
var
  I: Integer;
  Item: TJSONObject;
begin
  Result := nil;
  if Arr = nil then Exit;
  for I := 0 to Arr.Count - 1 do
    if Arr[I] is TJSONObject then
    begin
      Item := TJSONObject(Arr[I]);
      if SameText(Item.GetValue<string>('symbol'), Symbol) and
         SameText(Item.GetValue<string>('kind'), Kind) then
      begin
        Result := Item;
        Exit;
      end;
    end;
end;

function TDirectToolsAnalyzeCouplingTests.FindUsageWithMethod(Arr: TJSONArray;
  const Symbol, Kind, MethodFragment: string): TJSONObject;
var
  I: Integer;
  Item: TJSONObject;
  EncMethod: string;
begin
  Result := nil;
  if Arr = nil then Exit;
  for I := 0 to Arr.Count - 1 do
    if Arr[I] is TJSONObject then
    begin
      Item := TJSONObject(Arr[I]);
      EncMethod := Item.GetValue<string>('enclosing_method');
      if SameText(Item.GetValue<string>('symbol'), Symbol) and
         SameText(Item.GetValue<string>('kind'), Kind) and
         (Pos(LowerCase(MethodFragment), LowerCase(EncMethod)) > 0) then
      begin
        Result := Item;
        Exit;
      end;
    end;
end;

{ Setup / Teardown }

procedure TDirectToolsAnalyzeCouplingTests.SetupFixture;
var
  Timeout: Cardinal;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  Timeout := GetTickCount + 15000;
  while not FParser.IsReady and (GetTickCount < Timeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');
  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsAnalyzeCouplingTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

{ AnimalRegistry tests }

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_ResultHasRequiredKeys;
var
  Result: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Assert.IsNull(Result.GetValue('error'), 'Should have no error');
    Assert.IsNotNull(Result.GetValue('usages'), 'Should have usages key');
    Assert.IsNotNull(Result.GetValue('by_unit'), 'Should have by_unit key');
    Assert.IsNotNull(Result.GetValue('total_usages'), 'Should have total_usages key');
    Assert.IsNotNull(Result.GetValue('unit_name'), 'Should have unit_name key');
    Assert.IsNotNull(Result.GetValue('file'), 'Should have file key');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_UnitNameCorrect;
var
  Result: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Assert.AreEqual('AnimalRegistry', Result.GetValue<string>('unit_name'));
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_IAnimalFromAnimals;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  Found: Boolean;
  I: Integer;
  Item: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(Arr, 'usages must be array');
    Found := False;
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        if SameText(Item.GetValue<string>('symbol'), 'IAnimal') and
           SameText(Item.GetValue<string>('source_unit'), 'Animals') then
          Found := True;
      end;
    Assert.IsTrue(Found, 'Should find IAnimal with source_unit=Animals');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_FieldTypeDetected;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'IAnimal', 'field_type'),
      'Should find IAnimal as field_type');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_InterfaceParamTypeDetected;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Found: Boolean;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Found := False;
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        if SameText(Item.GetValue<string>('symbol'), 'IAnimal') and
           SameText(Item.GetValue<string>('kind'), 'param_type') and
           SameText(Item.GetValue<string>('enclosing_method'), 'RegisterAnimal') then
          Found := True;
      end;
    Assert.IsTrue(Found, 'Should find IAnimal param_type with enclosing_method="RegisterAnimal" (interface section)');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_ImplParamTypeDetected;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(
      FindUsageWithMethod(Arr, 'IAnimal', 'param_type', 'RegisterAnimal'),
      'Should find IAnimal param_type in RegisterAnimal implementation');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_InterfaceReturnTypeDetected;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Found: Boolean;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Found := False;
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        if SameText(Item.GetValue<string>('symbol'), 'IAnimal') and
           SameText(Item.GetValue<string>('kind'), 'return_type') and
           SameText(Item.GetValue<string>('enclosing_method'), 'FindAnimal') then
          Found := True;
      end;
    Assert.IsTrue(Found, 'Should find IAnimal return_type with enclosing_method="FindAnimal" (interface section)');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_ImplReturnTypeDetected;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(
      FindUsageWithMethod(Arr, 'IAnimal', 'return_type', 'FindAnimal'),
      'Should find IAnimal return_type in FindAnimal implementation');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_ByUnitHasAnimalsKey;
var
  Result: TJSONObject;
  ByUnit: TJSONValue;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    ByUnit := Result.GetValue('by_unit');
    Assert.IsNotNull(ByUnit, 'by_unit must exist');
    Assert.IsTrue(ByUnit.ToString.Contains('Animals'), 'by_unit should contain Animals key');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_ByUnitAnimalsSymbolsHasIAnimal;
var
  Result: TJSONObject;
  ByUnit: TJSONObject;
  AnimalsEntry: TJSONValue;
  Symbols: TJSONArray;
  I: Integer;
  Found: Boolean;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    if not (Result.GetValue('by_unit') is TJSONObject) then
    begin
      Assert.Fail('by_unit must be TJSONObject');
      Exit;
    end;
    ByUnit := TJSONObject(Result.GetValue('by_unit'));
    AnimalsEntry := ByUnit.GetValue('Animals');
    Assert.IsNotNull(AnimalsEntry, 'by_unit must have Animals entry');
    if AnimalsEntry is TJSONObject then
    begin
      Symbols := TJSONObject(AnimalsEntry).GetValue<TJSONArray>('symbols');
      Found := False;
      for I := 0 to Symbols.Count - 1 do
        if SameText(Symbols.Items[I].Value, 'IAnimal') then
          Found := True;
      Assert.IsTrue(Found, 'Animals symbols should contain IAnimal');
    end;
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_TotalUsagesPositive;
var
  Result: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Assert.IsTrue(Result.GetValue<Integer>('total_usages') >= 5,
      'total_usages should be at least 5');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_FieldTypeOnCorrectLine;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  Usage: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    Usage := FindUsage(Arr, 'IAnimal', 'field_type');
    Assert.IsNotNull(Usage, 'Should find IAnimal field_type');
    Assert.AreEqual(11, Usage.GetValue<Integer>('line'),
      'FAnimals field should be on line 11');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.AnimalRegistry_NoSelfReferences;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Result := CallCoupling(FProjectPath + '\AnimalRegistry.pas');
  try
    Arr := GetUsagesArr(Result);
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
        if Arr[I] is TJSONObject then
          Assert.IsFalse(
            SameText(TJSONObject(Arr[I]).GetValue<string>('source_unit'), 'AnimalRegistry'),
            'No usage should point back to AnimalRegistry itself');
  finally
    Result.Free;
  end;
end;

{ Dog tests }

procedure TDirectToolsAnalyzeCouplingTests.Dog_InheritanceCouplingFound;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Found: Boolean;
begin
  Result := CallCoupling(FProjectPath + '\Dog.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(Arr, 'usages must be array');
    Found := False;
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        if SameText(Item.GetValue<string>('symbol'), 'TAnimal') and
           SameText(Item.GetValue<string>('kind'), 'inheritance') and
           SameText(Item.GetValue<string>('source_unit'), 'Animals') then
          Found := True;
      end;
    Assert.IsTrue(Found, 'Dog.pas should show TAnimal inheritance from Animals');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.Dog_ByUnitHasAnimals;
var
  Result: TJSONObject;
  ByUnit: TJSONValue;
begin
  Result := CallCoupling(FProjectPath + '\Dog.pas');
  try
    ByUnit := Result.GetValue('by_unit');
    Assert.IsNotNull(ByUnit);
    Assert.IsTrue(ByUnit.ToString.Contains('Animals'),
      'by_unit should contain Animals');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.Dog_TotalUsagesPositive;
var
  Result: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\Dog.pas');
  try
    Assert.IsTrue(Result.GetValue<Integer>('total_usages') >= 1,
      'Dog.pas should have at least 1 coupling usage');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.Dog_NoSelfReference;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Result := CallCoupling(FProjectPath + '\Dog.pas');
  try
    Arr := GetUsagesArr(Result);
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
        if Arr[I] is TJSONObject then
          Assert.IsFalse(
            SameText(TJSONObject(Arr[I]).GetValue<string>('source_unit'), 'Dog'),
            'No usage should point back to Dog itself');
  finally
    Result.Free;
  end;
end;

{ Cat tests }

procedure TDirectToolsAnalyzeCouplingTests.Cat_InheritanceCouplingFound;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Found: Boolean;
begin
  Result := CallCoupling(FProjectPath + '\Cat.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(Arr);
    Found := False;
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        if SameText(Item.GetValue<string>('symbol'), 'TAnimal') and
           SameText(Item.GetValue<string>('kind'), 'inheritance') and
           SameText(Item.GetValue<string>('source_unit'), 'Animals') then
          Found := True;
      end;
    Assert.IsTrue(Found, 'Cat.pas should show TAnimal inheritance from Animals');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.Cat_ByUnitHasAnimals;
var
  Result: TJSONObject;
  ByUnit: TJSONValue;
begin
  Result := CallCoupling(FProjectPath + '\Cat.pas');
  try
    ByUnit := Result.GetValue('by_unit');
    Assert.IsNotNull(ByUnit);
    Assert.IsTrue(ByUnit.ToString.Contains('Animals'));
  finally
    Result.Free;
  end;
end;

{ CouplingDemo tests }

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_FieldTypeForTDog;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'TDog', 'field_type'),
      'Should find TDog as field_type');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_ParamTypeForIAnimal;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'IAnimal', 'param_type'),
      'Should find IAnimal as param_type');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_ReturnTypeForTDog;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'TDog', 'return_type'),
      'Should find TDog as return_type');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_LocalVarTAnimalKind;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'TAnimalKind', 'local_var'),
      'Should find TAnimalKind as local_var');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_LocalVarTDog;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'TDog', 'local_var'),
      'Should find TDog as local_var');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_QualifiedCallTDog;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(FindUsage(Arr, 'TDog', 'qualified_call'),
      'Should find TDog as qualified_call (TDog.Create)');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_ByUnitHasDog;
var
  Result: TJSONObject;
  ByUnit: TJSONValue;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    ByUnit := Result.GetValue('by_unit');
    Assert.IsNotNull(ByUnit);
    Assert.IsTrue(ByUnit.ToString.Contains('Dog'), 'by_unit should have Dog key');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_ByUnitHasAnimals;
var
  Result: TJSONObject;
  ByUnit: TJSONValue;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    ByUnit := Result.GetValue('by_unit');
    Assert.IsNotNull(ByUnit);
    Assert.IsTrue(ByUnit.ToString.Contains('Animals'), 'by_unit should have Animals key');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_TwoSourceUnits;
var
  Result: TJSONObject;
  ByUnit: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    if not (Result.GetValue('by_unit') is TJSONObject) then
    begin
      Assert.Fail('by_unit must be TJSONObject');
      Exit;
    end;
    ByUnit := TJSONObject(Result.GetValue('by_unit'));
    Assert.AreEqual(2, ByUnit.Count,
      'CouplingDemo should depend on exactly 2 units (Animals and Dog)');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.CouplingDemo_NoSelfReferences;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Result := CallCoupling(FProjectPath + '\CouplingDemo.pas');
  try
    Arr := GetUsagesArr(Result);
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
        if Arr[I] is TJSONObject then
          Assert.IsFalse(
            SameText(TJSONObject(Arr[I]).GetValue<string>('source_unit'), 'CouplingDemo'),
            'No usage should point back to CouplingDemo itself');
  finally
    Result.Free;
  end;
end;

{ Shapes (negative) tests }

procedure TDirectToolsAnalyzeCouplingTests.Shapes_TotalUsagesIsZero;
var
  Result: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\Shapes.pas');
  try
    Assert.AreEqual(0, Result.GetValue<Integer>('total_usages'),
      'Shapes.pas has no external dependencies');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.Shapes_UsagesArrayEmpty;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\Shapes.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(Arr);
    Assert.AreEqual(0, Arr.Count, 'Shapes.pas usages array should be empty');
  finally
    Result.Free;
  end;
end;

{ ProceduralUnit tests }

procedure TDirectToolsAnalyzeCouplingTests.ProceduralUnit_ParamTypeHasEnclosingMethod;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\ProceduralUnit.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(
      FindUsageWithMethod(Arr, 'IAnimal', 'param_type', 'RegisterDog'),
      'IAnimal param_type inside RegisterDog should have enclosing_method="RegisterDog"');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.ProceduralUnit_ReturnTypeHasEnclosingMethod;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\ProceduralUnit.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(
      FindUsageWithMethod(Arr, 'TDog', 'return_type', 'CreateDefaultDog'),
      'TDog return_type inside CreateDefaultDog should have enclosing_method="CreateDefaultDog"');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.ProceduralUnit_LocalVarHasEnclosingMethod;
var
  Result: TJSONObject;
  Arr: TJSONArray;
begin
  Result := CallCoupling(FProjectPath + '\ProceduralUnit.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(
      FindUsageWithMethod(Arr, 'TDog', 'local_var', 'ProcessAnimal'),
      'TDog local_var inside ProcessAnimal should have enclosing_method="ProcessAnimal"');
  finally
    Result.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.ProceduralUnit_EnclosingTypeIsAlwaysEmpty;
var
  Result: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
begin
  Result := CallCoupling(FProjectPath + '\ProceduralUnit.pas');
  try
    Arr := GetUsagesArr(Result);
    Assert.IsNotNull(Arr, 'usages array must exist');
    Assert.IsTrue(Arr.Count > 0, 'usages must be non-empty');
    for I := 0 to Arr.Count - 1 do
      if Arr[I] is TJSONObject then
      begin
        Item := TJSONObject(Arr[I]);
        Assert.AreEqual('', Item.GetValue<string>('enclosing_type'),
          Format('enclosing_type should be empty for usage at index %d', [I]));
      end;
  finally
    Result.Free;
  end;
end;

{ Error tests }

procedure TDirectToolsAnalyzeCouplingTests.MissingFileParam_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoAnalyzeCoupling(Params);
    try
      Assert.IsTrue(Result is TJSONObject);
      Assert.IsNotNull(TJSONObject(Result).GetValue('error'),
        'Missing file param should return error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsAnalyzeCouplingTests.NonExistentFile_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'C:\does\not\exist\Nonexistent.pas');
  try
    Result := FTools.DoAnalyzeCoupling(Params);
    try
      Assert.IsTrue(Result is TJSONObject);
      Assert.IsNotNull(TJSONObject(Result).GetValue('error'),
        'Nonexistent file should return error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsAnalyzeCouplingTests);
end.
