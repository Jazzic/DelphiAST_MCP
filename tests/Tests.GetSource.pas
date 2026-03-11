unit Tests.GetSource;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TGetSourceTests = class
  public
    [Test]
    procedure TDogSpeak_SourceContainsWoof;
  end;

implementation

uses
  MCP.TestHelper;

procedure TGetSourceTests.TDogSpeak_SourceContainsWoof;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Args := TJSONObject.Create;
  Args.AddPair('symbol', 'TDog.Speak');
  Args.AddPair('file', 'Dog.pas');
  try
    Result := TMCPTestHelper.CallTool('get_source', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONObject, 'Result should be a TJSONObject but was: ' + Result.ClassName);
      Obj := TJSONObject(Result);
      TMCPTestHelper.AssertStringContains(Obj.ToString, 'Woof');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
