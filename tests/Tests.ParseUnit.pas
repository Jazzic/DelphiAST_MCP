unit Tests.ParseUnit;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TParseUnitTests = class
  public
    [Test]
    procedure WithFile_ReturnsUnitOverview;
    [Test]
    procedure NoFile_ReturnsAllUnits;
  end;

implementation

uses
  MCP.TestHelper;

procedure TParseUnitTests.WithFile_ReturnsUnitOverview;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'Animals.pas');
  try
    Result := TMCPTestHelper.CallTool('parse_unit', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      Assert.AreEqual('Animals', Obj.GetValue<string>('unit_name', ''),
        'Unit name should be Animals');
      // Check types array contains TAnimal and IAnimal
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TAnimal');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'IAnimal');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TParseUnitTests.NoFile_ReturnsAllUnits;
var
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Result := TMCPTestHelper.CallTool('parse_unit');
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
    Arr := TJSONArray(Result);
    Assert.IsTrue(Arr.Count >= 5, 'Should have at least 5 units');
  finally
    Result.Free;
  end;
end;

end.
