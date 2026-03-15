unit Tests.DirectTools.SearchSymbols;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsSearchSymbolsTests = class
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

    // search_symbols tests
    [Test] procedure SearchBySubstring_FindsTypes;
    [Test] procedure SearchByKind_Method;
    [Test] procedure SearchByKind_Class;
    [Test] procedure ExactMatch_RankedFirst;
    [Test] procedure CaseInsensitive;
    [Test] procedure MaxResults_Limits;
    [Test] procedure NoMatch_ReturnsEmpty;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsSearchSymbolsTests }

procedure TDirectToolsSearchSymbolsTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsSearchSymbolsTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsSearchSymbolsTests.SearchBySubstring_FindsTypes;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  Found: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Animal');
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      // Should find TAnimal, TAnimalKind, TAnimalRegistry, IAnimal
      Assert.IsTrue(Arr.Count > 0, 'Should find at least one symbol');

      Found := False;
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr[I].GetValue<string>('name') = 'TAnimal' then
          Found := True;
      end;
      Assert.IsTrue(Found, 'Should find TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.SearchByKind_Method;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundSpeak: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Speak');
  Params.AddPair('kind', 'method');
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      // Should find Speak methods
      FoundSpeak := False;
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr[I].GetValue<string>('name') = 'Speak' then
        begin
          FoundSpeak := True;
          Assert.AreEqual('method', Arr[I].GetValue<string>('kind'), 'Should be method kind');
        end;
      end;
      Assert.IsTrue(FoundSpeak, 'Should find Speak method');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.SearchByKind_Class;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'Animal');  // Pattern that only matches types
  Params.AddPair('kind', 'class');
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      // Should only return classes
      for I := 0 to Arr.Count - 1 do
      begin
        Assert.AreEqual('class', Arr[I].GetValue<string>('kind'), 'Should be class kind');
      end;
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.ExactMatch_RankedFirst;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'TDog');
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      Assert.IsTrue(Arr.Count > 0, 'Should find at least one symbol');
      // First result should be TDog (exact match)
      Assert.AreEqual('TDog', Arr[0].GetValue<string>('name'), 'First result should be exact match TDog');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.CaseInsensitive;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  FoundTDog: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'tdog'); // lowercase
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      FoundTDog := False;
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr[I].GetValue<string>('name') = 'TDog' then
          FoundTDog := True;
      end;
      Assert.IsTrue(FoundTDog, 'Should find TDog with lowercase pattern (case-insensitive)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.MaxResults_Limits;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'T');
  Params.AddPair('max_results', 2);
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      Assert.IsTrue(Arr.Count <= 2, 'Should return at most 2 results');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsSearchSymbolsTests.NoMatch_ReturnsEmpty;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('pattern', 'ZZZZZNoMatchZZZZZ');
  try
    Result := FTools.DoSearchSymbols(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      Assert.AreEqual(0, Arr.Count, 'Should return empty array for no match');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsSearchSymbolsTests);
end.
