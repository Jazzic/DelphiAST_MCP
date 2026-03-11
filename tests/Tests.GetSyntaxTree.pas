unit Tests.GetSyntaxTree;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetSyntaxTreeTests = class
  public
    [Test]
    procedure Animals_RootNodePresent;
    [Test]
    procedure WithMaxDepth1_ShallowerTree;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetSyntaxTreeTests.Animals_RootNodePresent;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'Animals.pas');
  try
    Result := TMCPTestHelper.CallTool('get_syntax_tree', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      // Should have a 't' field (node type) at root
      Assert.IsNotNull(Obj.GetValue('t'), 'Root node should have type field (t)');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TGetSyntaxTreeTests.WithMaxDepth1_ShallowerTree;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'Animals.pas');
  Args.AddPair('max_depth', TJSONNumber.Create(1));
  try
    Result := TMCPTestHelper.CallTool('get_syntax_tree', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      Assert.IsNotNull(Obj.GetValue('t'), 'Root node should have type field (t)');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
