unit Tests.DirectTools.FindUsages;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsFindUsagesTests = class
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

    // find_usages tests
    [Test] procedure FName_Found;
    [Test] procedure GetName_Found;
    [Test] procedure Speak_Found;
    [Test] procedure FBreed_DogFile;
    [Test] procedure NonExistent_Empty;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsFindUsagesTests }

procedure TDirectToolsFindUsagesTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsFindUsagesTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsFindUsagesTests.FName_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'FName');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find usages of FName');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindUsagesTests.GetName_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'GetName');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find usages of GetName');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindUsagesTests.Speak_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'Speak');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find usages of Speak');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindUsagesTests.FBreed_DogFile;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'FBreed');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find usages of FBreed in Dog.pas');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindUsagesTests.NonExistent_Empty;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'NonExistentXYZ');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(0, Arr.Count, 'Should find no usages of NonExistentXYZ');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsFindUsagesTests);
end.
