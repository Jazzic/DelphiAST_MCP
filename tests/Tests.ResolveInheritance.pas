unit Tests.ResolveInheritance;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TResolveInheritanceTests = class
  public
    [Test]
    procedure TDog_ChainIncludesTAnimal;
    [Test]
    procedure TCircle_ChainIncludesTShape;
  end;

implementation

uses
  MCP.TestHelper;

procedure TResolveInheritanceTests.TDog_ChainIncludesTAnimal;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'TDog');
  try
    Result := TMCPTestHelper.CallTool('resolve_inheritance', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Chain should contain TDog -> TAnimal
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TDog');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TAnimal');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TResolveInheritanceTests.TCircle_ChainIncludesTShape;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'TCircle');
  try
    Result := TMCPTestHelper.CallTool('resolve_inheritance', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Chain should contain TCircle -> TShape
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TCircle');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TShape');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
