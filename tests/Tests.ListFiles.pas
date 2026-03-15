unit Tests.ListFiles;

interface

uses
  DUnitX.TestFramework, System.JSON;

type
  [TestFixture]
  TListFilesTests = class
  public
    [Test]
    procedure NoFilter_Returns6Files;
    [Test]
    procedure FilterDog_ReturnsDogOnly;
    [Test]
    procedure FilterNonexistent_ReturnsEmpty;
  end;

implementation

uses
  MCP.TestHelper;

procedure TListFilesTests.NoFilter_Returns6Files;
var
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Result := TMCPTestHelper.CallTool('list_files');
  try
    Assert.IsNotNull(Result, 'Result is nil');
    Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
    Arr := TJSONArray(Result);
    TMCPTestHelper.AssertArrayLength(Arr, 6);
    TMCPTestHelper.AssertArrayContains(Arr, 'Animals.pas');
    TMCPTestHelper.AssertArrayContains(Arr, 'Dog.pas');
    TMCPTestHelper.AssertArrayContains(Arr, 'Cat.pas');
    TMCPTestHelper.AssertArrayContains(Arr, 'AnimalRegistry.pas');
    TMCPTestHelper.AssertArrayContains(Arr, 'Shapes.pas');
    TMCPTestHelper.AssertArrayContains(Arr, 'TestProject.dpr');
  finally
    Result.Free;
  end;
end;

procedure TListFilesTests.FilterDog_ReturnsDogOnly;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Args := TJSONObject.Create;
  Args.AddPair('filter', 'dog');
  try
    Result := TMCPTestHelper.CallTool('list_files', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.AreEqual(1, Arr.Count, 'Should return exactly 1 file');
      TMCPTestHelper.AssertArrayContains(Arr, 'Dog.pas');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TListFilesTests.FilterNonexistent_ReturnsEmpty;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Args := TJSONObject.Create;
  Args.AddPair('filter', 'xyzxyz');
  try
    Result := TMCPTestHelper.CallTool('list_files', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.AreEqual(0, Arr.Count, 'Should return 0 files');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
