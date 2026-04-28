unit Tests.DirectTools.FindWeakCouplings;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsFindWeakCouplingsTests = class
  private
    class var FParser: TASTParser;
    class var FTools: TMCPTools;
    class var FProjectPath: string;

    function CallFind(Limit: Integer = 5; const ExcludeKinds: string = '';
      const Filter: string = ''): TJSONObject;
    function UnitEntry(Obj: TJSONObject; const UName: string): TJSONObject;
    function DepEntry(WeakDepsArr: TJSONArray; const DepUnit: string): TJSONObject;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test] procedure ResultHasTopLevelKeys;
    [Test] procedure TotalUnitsAnalyzed_Positive;
    [Test] procedure AllParsedUnitsInResult;
    [Test] procedure Shapes_EmptyWeakDeps;
    [Test] procedure Animals_EmptyWeakDeps;
    [Test] procedure Dog_WeakDepIsAnimals;
    [Test] procedure Dog_Tightness5_NoFilter;
    [Test] procedure ExcludeInheritance_Dog_NoDeps;
    [Test] procedure CouplingDemo_HasTwoDeps;
    [Test] procedure CouplingDemo_Animals_Weaker_Than_Dog;
    [Test] procedure Limit1_AtMostOneDep;
    [Test] procedure ExcludedKinds_InResponse;
    [Test] procedure NoFilter_DefaultLimit5;
    [Test] procedure Filter_ByName_LimitsUnits;
    [Test] procedure Filter_CaseInsensitive;
    [Test] procedure ExcludeMultiple_CommaSeparated;
    [Test] procedure Cast_Kind_Emitted;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ Helpers }

function TDirectToolsFindWeakCouplingsTests.CallFind(Limit: Integer;
  const ExcludeKinds, Filter: string): TJSONObject;
var
  Params: TJSONObject;
  Raw: TJSONValue;
begin
  Params := TJSONObject.Create;
  try
    Params.AddPair('limit', TJSONNumber.Create(Limit));
    if ExcludeKinds <> '' then
      Params.AddPair('exclude_kinds', ExcludeKinds);
    if Filter <> '' then
      Params.AddPair('filter', Filter);
    Raw := FTools.DoFindWeakCouplings(Params);
    Assert.IsTrue(Raw is TJSONObject, 'Result must be TJSONObject');
    Result := TJSONObject(Raw);
  finally
    Params.Free;
  end;
end;

function TDirectToolsFindWeakCouplingsTests.UnitEntry(Obj: TJSONObject;
  const UName: string): TJSONObject;
var
  UnitsArr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  V: TJSONValue;
begin
  Result := nil;
  if not Obj.TryGetValue('units', V) or not (V is TJSONArray) then
    Exit;
  UnitsArr := TJSONArray(V);
  for I := 0 to UnitsArr.Count - 1 do
    if UnitsArr[I] is TJSONObject then
    begin
      Item := TJSONObject(UnitsArr[I]);
      if SameText(Item.GetValue<string>('unit'), UName) then
      begin
        Result := Item;
        Exit;
      end;
    end;
end;

function TDirectToolsFindWeakCouplingsTests.DepEntry(WeakDepsArr: TJSONArray;
  const DepUnit: string): TJSONObject;
var
  I: Integer;
  Item: TJSONObject;
begin
  Result := nil;
  if WeakDepsArr = nil then Exit;
  for I := 0 to WeakDepsArr.Count - 1 do
    if WeakDepsArr[I] is TJSONObject then
    begin
      Item := TJSONObject(WeakDepsArr[I]);
      if SameText(Item.GetValue<string>('dependency_unit'), DepUnit) then
      begin
        Result := Item;
        Exit;
      end;
    end;
end;

{ Setup / Teardown }

procedure TDirectToolsFindWeakCouplingsTests.SetupFixture;
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

procedure TDirectToolsFindWeakCouplingsTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

{ Tests }

procedure TDirectToolsFindWeakCouplingsTests.ResultHasTopLevelKeys;
var
  Obj: TJSONObject;
begin
  Obj := CallFind;
  try
    Assert.IsNotNull(Obj.GetValue('units'),                'Should have units key');
    Assert.IsNotNull(Obj.GetValue('total_units_analyzed'), 'Should have total_units_analyzed key');
    Assert.IsNotNull(Obj.GetValue('excluded_kinds'),       'Should have excluded_kinds key');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.TotalUnitsAnalyzed_Positive;
var
  Obj: TJSONObject;
begin
  Obj := CallFind;
  try
    Assert.IsTrue(Obj.GetValue<Integer>('total_units_analyzed') >= 1,
      'At least one unit should be analyzed');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.AllParsedUnitsInResult;
var
  Obj: TJSONObject;
begin
  Obj := CallFind;
  try
    Assert.IsNotNull(UnitEntry(Obj, 'Animals'),       'Animals should appear');
    Assert.IsNotNull(UnitEntry(Obj, 'Dog'),           'Dog should appear');
    Assert.IsNotNull(UnitEntry(Obj, 'CouplingDemo'),  'CouplingDemo should appear');
    Assert.IsNotNull(UnitEntry(Obj, 'Shapes'),        'Shapes should appear');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Shapes_EmptyWeakDeps;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONValue;
begin
  Obj := CallFind;
  try
    Entry := UnitEntry(Obj, 'Shapes');
    Assert.IsNotNull(Entry, 'Shapes entry should exist');
    Deps := Entry.GetValue('weak_dependencies');
    Assert.IsNotNull(Deps, 'Shapes should have weak_dependencies key');
    Assert.IsTrue(Deps is TJSONArray, 'weak_dependencies should be array');
    Assert.AreEqual(0, TJSONArray(Deps).Count, 'Shapes should have no dependencies');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Animals_EmptyWeakDeps;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONValue;
begin
  Obj := CallFind;
  try
    Entry := UnitEntry(Obj, 'Animals');
    Assert.IsNotNull(Entry, 'Animals entry should exist');
    Deps := Entry.GetValue('weak_dependencies');
    Assert.IsNotNull(Deps, 'Animals should have weak_dependencies key');
    Assert.IsTrue(Deps is TJSONArray, 'weak_dependencies should be array');
    Assert.AreEqual(0, TJSONArray(Deps).Count, 'Animals should have no dependencies');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Dog_WeakDepIsAnimals;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONArray;
  Dep: TJSONObject;
begin
  Obj := CallFind;
  try
    Entry := UnitEntry(Obj, 'Dog');
    Assert.IsNotNull(Entry, 'Dog entry should exist');
    Deps  := TJSONArray(Entry.GetValue('weak_dependencies'));
    Assert.IsNotNull(Deps, 'Dog should have weak_dependencies');
    Assert.AreEqual(1, Deps.Count, 'Dog should have exactly one dependency');
    Dep := DepEntry(Deps, 'Animals');
    Assert.IsNotNull(Dep, 'Dog weak dep should be Animals');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Dog_Tightness5_NoFilter;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONArray;
  Dep: TJSONObject;
begin
  Obj := CallFind;
  try
    Entry := UnitEntry(Obj, 'Dog');
    Deps  := TJSONArray(Entry.GetValue('weak_dependencies'));
    Dep   := DepEntry(Deps, 'Animals');
    Assert.IsNotNull(Dep, 'Animals dep should exist for Dog');
    Assert.AreEqual(5, Dep.GetValue<Integer>('tightness'),
      'Inheritance coupling should give tightness 5');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.ExcludeInheritance_Dog_NoDeps;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONArray;
begin
  Obj := CallFind(5, 'inheritance');
  try
    Entry := UnitEntry(Obj, 'Dog');
    Assert.IsNotNull(Entry, 'Dog entry should exist');
    Deps := TJSONArray(Entry.GetValue('weak_dependencies'));
    Assert.AreEqual(0, Deps.Count,
      'Dog should have no deps after excluding inheritance');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.CouplingDemo_HasTwoDeps;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONArray;
begin
  Obj := CallFind;
  try
    Entry := UnitEntry(Obj, 'CouplingDemo');
    Assert.IsNotNull(Entry, 'CouplingDemo entry should exist');
    Deps := TJSONArray(Entry.GetValue('weak_dependencies'));
    Assert.AreEqual(2, Deps.Count, 'CouplingDemo should have exactly 2 dependencies');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.CouplingDemo_Animals_Weaker_Than_Dog;
var
  Obj: TJSONObject;
  Entry: TJSONObject;
  Deps: TJSONArray;
  AnimDep, DogDep: TJSONObject;
begin
  Obj := CallFind;
  try
    Entry   := UnitEntry(Obj, 'CouplingDemo');
    Deps    := TJSONArray(Entry.GetValue('weak_dependencies'));
    AnimDep := DepEntry(Deps, 'Animals');
    DogDep  := DepEntry(Deps, 'Dog');
    Assert.IsNotNull(AnimDep, 'Animals dep should exist');
    Assert.IsNotNull(DogDep,  'Dog dep should exist');
    Assert.IsTrue(
      AnimDep.GetValue<Integer>('tightness') < DogDep.GetValue<Integer>('tightness'),
      'Animals coupling should be weaker (lower tightness) than Dog coupling');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Limit1_AtMostOneDep;
var
  Obj: TJSONObject;
  UnitsArr: TJSONArray;
  I: Integer;
  Entry: TJSONObject;
  Deps: TJSONArray;
  V: TJSONValue;
begin
  Obj := CallFind(1);
  try
    Obj.TryGetValue('units', V);
    UnitsArr := TJSONArray(V);
    for I := 0 to UnitsArr.Count - 1 do
    begin
      Entry := TJSONObject(UnitsArr[I]);
      Deps  := TJSONArray(Entry.GetValue('weak_dependencies'));
      Assert.IsTrue(Deps.Count <= 1,
        'Each unit should have at most 1 dep when limit=1');
    end;
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.ExcludedKinds_InResponse;
var
  Obj: TJSONObject;
  V: TJSONValue;
  ExcArr: TJSONArray;
  Found: Boolean;
  I: Integer;
begin
  Obj := CallFind(5, 'inheritance');
  try
    Obj.TryGetValue('excluded_kinds', V);
    Assert.IsTrue(V is TJSONArray, 'excluded_kinds should be array');
    ExcArr := TJSONArray(V);
    Found  := False;
    for I := 0 to ExcArr.Count - 1 do
      if SameText(ExcArr[I].Value, 'inheritance') then
      begin
        Found := True;
        Break;
      end;
    Assert.IsTrue(Found, 'excluded_kinds should contain "inheritance"');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.NoFilter_DefaultLimit5;
var
  Obj: TJSONObject;
  UnitsArr: TJSONArray;
  I: Integer;
  Entry: TJSONObject;
  Deps: TJSONArray;
  V: TJSONValue;
begin
  Obj := CallFind; // default limit = 5
  try
    Obj.TryGetValue('units', V);
    UnitsArr := TJSONArray(V);
    for I := 0 to UnitsArr.Count - 1 do
    begin
      Entry := TJSONObject(UnitsArr[I]);
      Deps  := TJSONArray(Entry.GetValue('weak_dependencies'));
      Assert.IsTrue(Deps.Count <= 5, 'No unit should have more than 5 deps with default limit');
    end;
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Filter_ByName_LimitsUnits;
var
  Obj: TJSONObject;
  V: TJSONValue;
  UnitsArr: TJSONArray;
begin
  Obj := CallFind(5, '', 'Dog');
  try
    Obj.TryGetValue('units', V);
    UnitsArr := TJSONArray(V);
    Assert.AreEqual(1, UnitsArr.Count, 'Only Dog.pas should appear with filter=Dog');
    Assert.IsNotNull(UnitEntry(Obj, 'Dog'), 'Dog should be in results');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Filter_CaseInsensitive;
var
  Obj: TJSONObject;
  V: TJSONValue;
  UnitsArr: TJSONArray;
begin
  Obj := CallFind(5, '', 'dog');
  try
    Obj.TryGetValue('units', V);
    UnitsArr := TJSONArray(V);
    Assert.IsTrue(UnitsArr.Count >= 1, 'dog (lowercase) should match Dog.pas');
    Assert.IsNotNull(UnitEntry(Obj, 'Dog'), 'Dog should appear with lowercase filter');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.ExcludeMultiple_CommaSeparated;
var
  Obj: TJSONObject;
  V: TJSONValue;
  ExcArr: TJSONArray;
  I: Integer;
  HasInheritance, HasFieldType: Boolean;
begin
  Obj := CallFind(5, 'inheritance,field_type');
  try
    Obj.TryGetValue('excluded_kinds', V);
    ExcArr := TJSONArray(V);
    HasInheritance := False;
    HasFieldType   := False;
    for I := 0 to ExcArr.Count - 1 do
    begin
      if SameText(ExcArr[I].Value, 'inheritance') then HasInheritance := True;
      if SameText(ExcArr[I].Value, 'field_type')  then HasFieldType   := True;
    end;
    Assert.IsTrue(HasInheritance, 'excluded_kinds should contain inheritance');
    Assert.IsTrue(HasFieldType,   'excluded_kinds should contain field_type');
  finally
    Obj.Free;
  end;
end;

procedure TDirectToolsFindWeakCouplingsTests.Cast_Kind_Emitted;
var
  Params: TJSONObject;
  Raw: TJSONObject;
  UsagesArr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Found: Boolean;
  V: TJSONValue;
begin
  // Use analyze_coupling directly to confirm CouplingDemo.DoCast emits 'cast' for TDog
  Params := TJSONObject.Create;
  Params.AddPair('file', FProjectPath + '\CouplingDemo.pas');
  try
    Raw := TJSONObject(FTools.DoAnalyzeCoupling(Params));
    try
      Raw.TryGetValue('usages', V);
      Assert.IsTrue(V is TJSONArray, 'usages should be array');
      UsagesArr := TJSONArray(V);
      Found := False;
      for I := 0 to UsagesArr.Count - 1 do
        if UsagesArr[I] is TJSONObject then
        begin
          Item := TJSONObject(UsagesArr[I]);
          if SameText(Item.GetValue<string>('symbol'), 'TDog') and
             SameText(Item.GetValue<string>('kind'), 'cast') then
          begin
            Found := True;
            Break;
          end;
        end;
      Assert.IsTrue(Found, 'CouplingDemo.DoCast should produce a cast usage for TDog');
    finally
      Raw.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsFindWeakCouplingsTests);
end.
