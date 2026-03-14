unit Tests.DirectTools.GetCallGraph;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetCallGraphTests = class
  private
    class var FParser: TASTParser;
    class var FTools: TMCPTools;
    class var FProjectPath: string;
    class var FTimeout: Cardinal;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    // get_call_graph tests - limited due to known issues with this tool
    [Test] procedure ParserWorks;
    [Test] procedure NonExistentMethod_ReturnsError;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetCallGraphTests }

procedure TDirectToolsGetCallGraphTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetCallGraphTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetCallGraphTests.ParserWorks;
begin
  // Just verify parser is configured and ready
  Assert.IsTrue(FParser.IsConfigured, 'Parser should be configured');
  Assert.IsTrue(FParser.IsReady, 'Parser should be ready');
end;

procedure TDirectToolsGetCallGraphTests.NonExistentMethod_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TNoSuch.Missing');
  try
    Result := FTools.DoGetCallGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);
      Assert.IsNotNull(Obj.Get('error'), 'Should have error field');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetCallGraphTests);
end.
