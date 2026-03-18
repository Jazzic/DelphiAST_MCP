unit Tests.DirectTools.ListFiles;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsListFilesTests = class
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

    // list_files tests
    [Test] procedure NoFilter_ReturnsAll6Files;
    [Test] procedure FilterDog_ReturnsOne;
    [Test] procedure FilterAnimal_ReturnsTwo;
    [Test] procedure FilterNonExistent_ReturnsEmpty;
    [Test] procedure FilterCaseInsensitive;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows;

function ArrayContainsValue(Arr: TJSONArray; const Value: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Arr.Count - 1 do
  begin
    if Arr.Items[I].Value = Value then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ TDirectToolsListFilesTests }

procedure TDirectToolsListFilesTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  // Wait for background parse to complete (5 files, should be < 1 second)
  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsListFilesTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsListFilesTests.NoFilter_ReturnsAll6Files;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  try
    Result := FTools.DoListFiles(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(7, Arr.Count, 'Should have 7 files');

      // Check all expected files are present
      Assert.IsTrue(ArrayContainsValue(Arr, 'Animals.pas'), 'Should contain Animals.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'Dog.pas'), 'Should contain Dog.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'Cat.pas'), 'Should contain Cat.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'AnimalRegistry.pas'), 'Should contain AnimalRegistry.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'Shapes.pas'), 'Should contain Shapes.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'TestForwardDecl.pas'), 'Should contain TestForwardDecl.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'TestProject.dpr'), 'Should contain TestProject.dpr');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsListFilesTests.FilterDog_ReturnsOne;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('filter', 'Dog');
  try
    Result := FTools.DoListFiles(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(1, Arr.Count, 'Should have 1 file matching Dog');
      Assert.AreEqual('Dog.pas', Arr.Items[0].Value, 'Should be Dog.pas');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsListFilesTests.FilterAnimal_ReturnsTwo;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('filter', 'Animal');
  try
    Result := FTools.DoListFiles(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(2, Arr.Count, 'Should have 2 files matching Animal');

      // Should contain Animals.pas and AnimalRegistry.pas
      Assert.IsTrue(ArrayContainsValue(Arr, 'Animals.pas'), 'Should contain Animals.pas');
      Assert.IsTrue(ArrayContainsValue(Arr, 'AnimalRegistry.pas'), 'Should contain AnimalRegistry.pas');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsListFilesTests.FilterNonExistent_ReturnsEmpty;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('filter', 'xyzxyz');
  try
    Result := FTools.DoListFiles(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(0, Arr.Count, 'Should have 0 files matching xyzxyz');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsListFilesTests.FilterCaseInsensitive;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('filter', 'dog'); // lowercase
  try
    Result := FTools.DoListFiles(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.AreEqual(1, Arr.Count, 'Should have 1 file matching dog (case-insensitive)');
      Assert.AreEqual('Dog.pas', Arr.Items[0].Value, 'Should be Dog.pas');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsListFilesTests);
end.
