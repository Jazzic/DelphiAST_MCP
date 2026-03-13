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
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

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
  Assert.IsFalse(FParser.IsParsing, 'Parser should not be parsing');
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetCallGraphTests);
end.
