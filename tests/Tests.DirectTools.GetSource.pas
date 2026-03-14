unit Tests.DirectTools.GetSource;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetSourceTests = class
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

    // get_source tests
    [Test] procedure ByLineRange_DogHeader;
    [Test] procedure ByLineRange_CatBody;
    [Test] procedure SymbolNotFound_ReturnsError;
    [Test] procedure MissingParams_ReturnsError;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetSourceTests }

procedure TDirectToolsGetSourceTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetSourceTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetSourceTests.ByLineRange_DogHeader;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  Params.AddPair('start_line', 1);
  Params.AddPair('end_line', 5);
  try
    Result := FTools.DoGetSource(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('source'), 'Should have source');
      Assert.IsNotNull(Obj.Get('start_line'), 'Should have start_line');
      Assert.IsNotNull(Obj.Get('end_line'), 'Should have end_line');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSourceTests.ByLineRange_CatBody;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Cat.pas');
  Params.AddPair('start_line', 20);
  Params.AddPair('end_line', 30);
  try
    Result := FTools.DoGetSource(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('source'), 'Should have source');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSourceTests.SymbolNotFound_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('symbol', 'TNoSuch.Foo');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetSource(Params);
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

procedure TDirectToolsGetSourceTests.MissingParams_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  // No symbol, no file, no lines - should return error
  try
    Result := FTools.DoGetSource(Params);
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
  TDUnitX.RegisterTestFixture(TDirectToolsGetSourceTests);
end.
