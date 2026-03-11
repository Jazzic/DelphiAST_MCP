unit Tests.GetUsesGraph;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetUsesGraphTests = class
  public
    [Test]
    procedure AnimalRegistry_UsesAnimalsAndDogAndCat;
    [Test]
    procedure AnimalRegistry_ImplementationUsesSysUtils;
    [Test]
    procedure Animals_UsedByDogCatAndRegistry;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetUsesGraphTests.AnimalRegistry_UsesAnimalsAndDogAndCat;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := TMCPTestHelper.CallTool('get_uses_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Animals');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Dog');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Cat');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetUsesGraphTests.AnimalRegistry_ImplementationUsesSysUtils;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := TMCPTestHelper.CallTool('get_uses_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Implementation uses SysUtils (via Exception in Fetch method)
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'SysUtils');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetUsesGraphTests.Animals_UsedByDogCatAndRegistry;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'Animals.pas');
  try
    Result := TMCPTestHelper.CallTool('get_uses_graph', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Animals is used by Dog.pas, Cat.pas, AnimalRegistry.pas
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Dog');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Cat');
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'AnimalRegistry');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
