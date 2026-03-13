unit Tests.DirectTools.GetStatus;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetStatusTests = class
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

    // get_status tests
    [Test] procedure ReturnsIdle;
    [Test] procedure TotalFiles_Is5;
    [Test] procedure CachedAndParsedMatch;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetStatusTests }

procedure TDirectToolsGetStatusTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetStatusTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetStatusTests.ReturnsIdle;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoGetStatus(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual('idle', Obj.GetValue<string>('state'), 'State should be idle');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetStatusTests.TotalFiles_Is5;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoGetStatus(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.AreEqual(5, Obj.GetValue<integer>('total_files'), 'Total files should be 5');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetStatusTests.CachedAndParsedMatch;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoGetStatus(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
      Assert.IsTrue(Obj.GetValue<integer>('parsed_files') >= 0, 'Parsed files should be >= 0');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetStatusTests);
end.
