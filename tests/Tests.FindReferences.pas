unit Tests.FindReferences;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TFindReferencesTests = class
  public
    [Test]
    procedure TAnimal_FoundInMultipleFiles;
    [Test]
    procedure TAnimalKindType_FilteredCorrectly;
    [Test]
    procedure Speak_MethodKind_ReturnsThreeMethods;
  end;

implementation

uses
  MCP.TestHelper;

procedure TFindReferencesTests.TAnimal_FoundInMultipleFiles;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Args := TJSONObject.Create;
  Args.AddPair('pattern', 'TAnimal');
  try
    Result := TMCPTestHelper.CallTool('find_references', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count >= 2, 'Should find TAnimal in at least 2 files');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TFindReferencesTests.TAnimalKindType_FilteredCorrectly;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemKind: string;
begin
  Args := TJSONObject.Create;
  Args.AddPair('pattern', 'TAnimalKind');
  Args.AddPair('kind', 'type');
  try
    Result := TMCPTestHelper.CallTool('find_references', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count >= 1, 'Should find at least 1 type reference');
      // All items should be type declarations
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr[I] is TJSONObject then
        begin
          Obj := TJSONObject(Arr[I]);
          ItemKind := Obj.GetValue<string>('kind', '');
          Assert.AreEqual('type', ItemKind, 'All items should have kind=type');
        end;
      end;
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TFindReferencesTests.Speak_MethodKind_ReturnsThreeMethods;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Args := TJSONObject.Create;
  Args.AddPair('pattern', 'Speak');
  Args.AddPair('kind', 'method');
  try
    Result := TMCPTestHelper.CallTool('find_references', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count >= 3, 'Should find at least 3 Speak methods (TAnimal, TDog, TCat)');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
