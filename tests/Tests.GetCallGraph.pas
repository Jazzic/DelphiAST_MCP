unit Tests.GetCallGraph;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetCallGraphTests = class
  public
    [Test]
    procedure TDogFetch_CalleesIncludesExceptionCreate;
    [Test]
    procedure TAnimalRegistryFindAnimal_CalleesIncludesGetName;
    [Test]
    procedure TAnimalGetName_CallersIncludesFindAnimal;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetCallGraphTests.TDogFetch_CalleesIncludesExceptionCreate;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TDog.Fetch');
  Args.AddPair('direction', 'callees');
  try
    Result := TMCPTestHelper.CallTool('get_call_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Fetch calls Exception.Create (in raise statement)
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Exception');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetCallGraphTests.TAnimalRegistryFindAnimal_CalleesIncludesGetName;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TAnimalRegistry.FindAnimal');
  Args.AddPair('direction', 'callees');
  try
    Result := TMCPTestHelper.CallTool('get_call_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // FindAnimal calls GetName on each animal
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'GetName');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetCallGraphTests.TAnimalGetName_CallersIncludesFindAnimal;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TAnimal.GetName');
  Args.AddPair('direction', 'callers');
  try
    Result := TMCPTestHelper.CallTool('get_call_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // FindAnimal is a caller of GetName
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'FindAnimal');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
