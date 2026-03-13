unit Tests.DirectTools.GetUsesGraph;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetUsesGraphTests = class
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

    // get_uses_graph tests
    [Test] procedure Dog_UsesAnimals;
    [Test] procedure Cat_UsesAnimals;
    [Test] procedure AnimalRegistry_Uses3Units;
    [Test] procedure Animals_Found;
    [Test] procedure Shapes_Found;
    [Test] procedure Animals_UsedByFiles;
    [Test] procedure Dog_UsedByRegistry;
    [Test] procedure Shapes_UsedByNone;
    [Test] procedure AnimalRegistry_UsedByNone;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

function ArrayContainsValue(Arr: TJSONArray; const Value: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Arr = nil then Exit;
  for I := 0 to Arr.Count - 1 do
  begin
    if Arr.Items[I].Value = Value then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ TDirectToolsGetUsesGraphTests }

procedure TDirectToolsGetUsesGraphTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetUsesGraphTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetUsesGraphTests.Dog_UsesAnimals;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('uses_interface'), 'Should have uses_interface');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Cat_UsesAnimals;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Cat.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('uses_interface'), 'Should have uses_interface');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.AnimalRegistry_Uses3Units;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  UsesInt: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      UsesInt := Obj.GetValue<TJSONArray>('uses_interface');
      Assert.IsNotNull(UsesInt, 'Should have uses_interface');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Animals'), 'Should contain Animals');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Dog'), 'Should contain Dog');
      Assert.IsTrue(ArrayContainsValue(UsesInt, 'Cat'), 'Should contain Cat');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Animals_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Shapes_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Animals_UsedByFiles;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  UsedBy: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      UsedBy := Obj.GetValue<TJSONArray>('used_by');
      Assert.IsNotNull(UsedBy, 'Should have used_by');
      Assert.IsTrue(UsedBy.Count >= 2, 'Should be used by at least 2 files');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Dog_UsedByRegistry;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  UsedBy: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      UsedBy := Obj.GetValue<TJSONArray>('used_by');
      Assert.IsNotNull(UsedBy, 'Should have used_by');
      Assert.IsTrue(UsedBy.Count >= 1, 'Should be used by at least 1 file');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.Shapes_UsedByNone;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetUsesGraphTests.AnimalRegistry_UsedByNone;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'AnimalRegistry.pas');
  try
    Result := FTools.DoGetUsesGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetUsesGraphTests);
end.
