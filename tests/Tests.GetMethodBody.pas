unit Tests.GetMethodBody;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetMethodBodyTests = class
  public
    [Test]
    procedure TDogSpeak_HasResultAssignment;
    [Test]
    procedure TDogFetch_HasIfAndRaise;
    [Test]
    procedure TAnimalRegistryFindAnimal_HasForLoop;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetMethodBodyTests.TDogSpeak_HasResultAssignment;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TDog.Speak');
  try
    Result := TMCPTestHelper.CallTool('get_method_body', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Result'); // Should have result assignment
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetMethodBodyTests.TDogFetch_HasIfAndRaise;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TDog.Fetch');
  try
    Result := TMCPTestHelper.CallTool('get_method_body', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'if');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'raise');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetMethodBodyTests.TAnimalRegistryFindAnimal_HasForLoop;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TAnimalRegistry.FindAnimal');
  try
    Result := TMCPTestHelper.CallTool('get_method_body', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'for');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
