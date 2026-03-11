unit Tests.Errors;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TErrorTests = class
  public
    [Test]
    procedure GetTypeDetail_MissingTypeName_IsError;
    [Test]
    procedure GetMethodBody_NonexistentMethod_IsError;
    [Test]
    procedure GetUsesGraph_NonexistentFile_IsError;
  end;

implementation

uses
  MCP.TestHelper;

procedure TErrorTests.GetTypeDetail_MissingTypeName_IsError;
var
  Args: TJSONObject;
begin
  // Call with empty args (no type_name)
  Args := TJSONObject.Create;
  try
    TMCPTestHelper.CallTool('get_type_detail', Args, True);
  finally
    Args.Free;
  end;
end;

procedure TErrorTests.GetMethodBody_NonexistentMethod_IsError;
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('method_name', 'TNoSuchClass.NoSuchMethod');
  try
    // Should return error or empty result
    TMCPTestHelper.CallTool('get_method_body', Args, True);
  finally
    Args.Free;
  end;
end;

procedure TErrorTests.GetUsesGraph_NonexistentFile_IsError;
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('file', 'doesnotexist.pas');
  try
    TMCPTestHelper.CallTool('get_uses_graph', Args, True);
  finally
    Args.Free;
  end;
end;

end.
