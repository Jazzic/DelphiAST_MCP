unit Tests.DirectTools.FindDescendants;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsFindDescendantsTests = class
  private
    class var FParser: TASTParser;
    class var FTools: TMCPTools;
    class var FProjectPath: string;
    class var FTimeout: Cardinal;
    class function FindNodeInTree(Arr: TJSONArray; const Name: string): TJSONObject;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    // find_descendants tests
    [Test] procedure TAnimal_HasDirectChildren;
    [Test] procedure TShape_HasDirectChildren;
    [Test] procedure IAnimal_TransitivelyFindsImplementors;
    [Test] procedure IAnimal_DirectOnly;
    [Test] procedure TDog_NoDescendants;
    [Test] procedure NonExistent_ReturnsEmpty;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsFindDescendantsTests }

class function TDirectToolsFindDescendantsTests.FindNodeInTree(Arr: TJSONArray; const Name: string): TJSONObject;
var
  I: Integer;
  Obj: TJSONObject;
  ChildResult: TJSONObject;
begin
  Result := nil;
  if Arr = nil then
    Exit;
  for I := 0 to Arr.Count - 1 do
  begin
    Obj := Arr[I] as TJSONObject;
    if Obj.GetValue<string>('name') = Name then
      Exit(Obj);
    // Recurse into descendants
    ChildResult := FindNodeInTree(Obj.GetValue<TJSONArray>('descendants'), Name);
    if ChildResult <> nil then
      Exit(ChildResult);
  end;
end;

procedure TDirectToolsFindDescendantsTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsFindDescendantsTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsFindDescendantsTests.TAnimal_HasDirectChildren;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  DogNode, CatNode: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimal');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TAnimal', Obj.GetValue<string>('type_name'), 'Type name should be TAnimal');
      Assert.IsNotNull(Obj.Get('descendants'), 'Should have descendants');

      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // TDog and TCat should be direct children at root level
      DogNode := FindNodeInTree(Descendants, 'TDog');
      CatNode := FindNodeInTree(Descendants, 'TCat');
      Assert.IsNotNull(DogNode, 'Should find TDog as descendant of TAnimal');
      Assert.IsNotNull(CatNode, 'Should find TCat as descendant of TAnimal');

      // Each should have a descendants array
      Assert.IsNotNull(DogNode.GetValue<TJSONArray>('descendants'), 'TDog should have descendants array');
      Assert.IsNotNull(CatNode.GetValue<TJSONArray>('descendants'), 'TCat should have descendants array');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.TShape_HasDirectChildren;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  CircleNode, RectNode: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TShape');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      CircleNode := FindNodeInTree(Descendants, 'TCircle');
      RectNode := FindNodeInTree(Descendants, 'TRectangle');
      Assert.IsNotNull(CircleNode, 'Should find TCircle as descendant of TShape');
      Assert.IsNotNull(RectNode, 'Should find TRectangle as descendant of TShape');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.IAnimal_TransitivelyFindsImplementors;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  AnimalNode: TJSONObject;
  AnimalChildren: TJSONArray;
  DogNode, CatNode: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'IAnimal');
  // No max_depth = unlimited (default 0)
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // TAnimal should be at root level (direct child of IAnimal)
      AnimalNode := FindNodeInTree(Descendants, 'TAnimal');
      Assert.IsNotNull(AnimalNode, 'Should find TAnimal as implementor of IAnimal');
      Assert.AreEqual(1, AnimalNode.GetValue<Integer>('depth'), 'TAnimal should be at depth 1');

      // TDog and TCat should be NESTED inside TAnimal's descendants
      AnimalChildren := AnimalNode.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(AnimalChildren, 'TAnimal should have descendants array');

      DogNode := FindNodeInTree(AnimalChildren, 'TDog');
      CatNode := FindNodeInTree(AnimalChildren, 'TCat');
      Assert.IsNotNull(DogNode, 'Should find TDog nested under TAnimal');
      Assert.IsNotNull(CatNode, 'Should find TCat nested under TAnimal');
      Assert.AreEqual(2, DogNode.GetValue<Integer>('depth'), 'TDog should be at depth 2');
      Assert.AreEqual(2, CatNode.GetValue<Integer>('depth'), 'TCat should be at depth 2');

      // Total count should be 3
      Assert.AreEqual(3, Obj.GetValue<Integer>('count'), 'Total count should be 3');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.IAnimal_DirectOnly;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  AnimalNode: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'IAnimal');
  Params.AddPair('max_depth', 1);
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // With max_depth=1, should only find TAnimal (direct implementor)
      AnimalNode := FindNodeInTree(Descendants, 'TAnimal');
      Assert.IsNotNull(AnimalNode, 'Should find TAnimal as direct implementor of IAnimal');

      // TDog and TCat should NOT appear anywhere in the tree
      Assert.IsNull(FindNodeInTree(Descendants, 'TDog'), 'Should NOT find TDog with max_depth=1');
      Assert.IsNull(FindNodeInTree(Descendants, 'TCat'), 'Should NOT find TCat with max_depth=1');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.TDog_NoDescendants;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');
      Assert.AreEqual(0, Descendants.Count, 'TDog should have no descendants');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.NonExistent_ReturnsEmpty;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TNonExistentType');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      // Non-existent should return empty, not an error
      Assert.IsNull(Obj.Get('error'), 'Should not have error for non-existent type');
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');
      Assert.AreEqual(0, Descendants.Count, 'Non-existent type should have no descendants');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsFindDescendantsTests);
end.
