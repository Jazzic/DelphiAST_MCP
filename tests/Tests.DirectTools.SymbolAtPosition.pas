unit Tests.DirectTools.SymbolAtPosition;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsSymbolAtPositionTests = class
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

    // symbol_at_position tests
    [Test] procedure DogFile_ValidPosition;
    [Test] procedure AnimalsFile_ValidPosition;
    [Test] procedure InvalidPosition_ReturnsError;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsSymbolAtPositionTests }

procedure TDirectToolsSymbolAtPositionTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsSymbolAtPositionTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsSymbolAtPositionTests.DogFile_ValidPosition;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  Params.AddPair('line', 10);
  Params.AddPair('col', 5);
  try
    Result := FTools.DoSymbolAtPosition(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      // Should either find something or return error for no node
      Assert.IsNotNull(Obj.Get('type'), 'Should have type field');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSymbolAtPositionTests.AnimalsFile_ValidPosition;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  Params.AddPair('line', 20);
  Params.AddPair('col', 5);
  try
    Result := FTools.DoSymbolAtPosition(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNotNull(Obj.Get('type'), 'Should have type field');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSymbolAtPositionTests.InvalidPosition_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  Params.AddPair('line', 999);
  Params.AddPair('col', 1);
  try
    Result := FTools.DoSymbolAtPosition(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      // Should have error for position beyond file
      Assert.IsNotNull(Obj.Get('error'), 'Should have error for invalid position');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsSymbolAtPositionTests);
end.
