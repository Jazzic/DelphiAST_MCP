unit Tests.GetTypeDetail;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetTypeDetailTests = class
  public
    [Test]
    procedure TDog_HasExpectedMembers;
    [Test]
    procedure IAnimal_IsInterface;
    [Test]
    procedure TAnimalKind_IsEnum;
    [Test]
    procedure NonExistent_ReturnsError;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetTypeDetailTests.TDog_HasExpectedMembers;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'TDog');
  try
    Result := TMCPTestHelper.CallTool('get_type_detail', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      Assert.AreEqual('class', Obj.GetValue<string>('kind', ''), 'Kind should be class');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'TAnimal'); // ancestor
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'FBreed'); // field
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Speak'); // method
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetTypeDetailTests.IAnimal_IsInterface;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'IAnimal');
  try
    Result := TMCPTestHelper.CallTool('get_type_detail', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      Assert.AreEqual('interface', Obj.GetValue<string>('kind', ''), 'Kind should be interface');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'animals.pas');
      // Should have methods with GetName and Speak
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'GetName');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Speak');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetTypeDetailTests.TAnimalKind_IsEnum;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'TAnimalKind');
  try
    Result := TMCPTestHelper.CallTool('get_type_detail', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      Assert.AreEqual('enum', Obj.GetValue<string>('kind', ''), 'Kind should be enum');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetTypeDetailTests.NonExistent_ReturnsError;
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('type_name', 'TNonExistentXYZ');
  try
    // Should return error or empty result
    TMCPTestHelper.CallTool('get_type_detail', Args, True);
  finally
    Args.Free;
  end;
end;

end.
