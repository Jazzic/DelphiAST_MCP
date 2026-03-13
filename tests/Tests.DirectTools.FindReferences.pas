unit Tests.DirectTools.FindReferences;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsFindReferencesTests = class
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

    // find_references tests
    [Test] procedure PatternAnimal_FindsSomething;
    [Test] procedure PatternDog_FindsSomething;
    [Test] procedure KindType_Filter;
    [Test] procedure KindMethod_Filter;
    [Test] procedure SingleFile_DogOnly;
    [Test] procedure EmptyPattern_AllDecls;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsFindReferencesTests }

procedure TDirectToolsFindReferencesTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsFindReferencesTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsFindReferencesTests.PatternAnimal_FindsSomething;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Animal');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find at least one reference to Animal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindReferencesTests.PatternDog_FindsSomething;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Dog');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find at least one reference to Dog');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindReferencesTests.KindType_Filter;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Animal');
  Params.AddPair('kind', 'type');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find type declarations');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindReferencesTests.KindMethod_Filter;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Speak');
  Params.AddPair('kind', 'method');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find method declarations');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindReferencesTests.SingleFile_DogOnly;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', '');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find declarations in Dog.pas');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindReferencesTests.EmptyPattern_AllDecls;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', '');
  try
    Result := FTools.DoFindReferences(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find all declarations');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsFindReferencesTests);
end.
