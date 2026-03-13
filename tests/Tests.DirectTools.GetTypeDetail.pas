unit Tests.DirectTools.GetTypeDetail;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetTypeDetailTests = class
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

    // get_type_detail tests - testing class types only
    [Test] procedure TDog_IsClass;
    [Test] procedure TAnimal_IsClass;
    [Test] procedure TCircle_IsClass;
    [Test] procedure TRectangle_IsClass;
    [Test] procedure TCat_IsClass;
    [Test] procedure TShape_IsClass;
    [Test] procedure IAnimal_IsInterface;
    [Test] procedure NoFile_SearchesAllParsed;
    [Test] procedure NonExistent_ReturnsError;
    [Test] procedure NonExistent_NoFile_RaisesException;
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

{ TDirectToolsGetTypeDetailTests }

procedure TDirectToolsGetTypeDetailTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  // Wait for background parse to complete
  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetTypeDetailTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetTypeDetailTests.TDog_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      // Should not have error
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TDog', Obj.GetValue<string>('name'), 'Type name should be TDog');
      Assert.IsNotNull(Obj.Get('line'), 'Should have line');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.TAnimal_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimal');
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TAnimal', Obj.GetValue<string>('name'), 'Type name should be TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.TCircle_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TCircle');
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TCircle', Obj.GetValue<string>('name'), 'Type name should be TCircle');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.TRectangle_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TRectangle');
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
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

procedure TDirectToolsGetTypeDetailTests.TCat_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TCat');
  Params.AddPair('file', 'Cat.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
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

procedure TDirectToolsGetTypeDetailTests.TShape_IsClass;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TShape');
  Params.AddPair('file', 'Shapes.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TShape', Obj.GetValue<string>('name'), 'Type name should be TShape');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.IAnimal_IsInterface;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Methods: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'IAnimal');
  Params.AddPair('file', 'Animals.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('IAnimal', Obj.GetValue<string>('name'), 'Type name should be IAnimal');
      Assert.AreEqual('interface', Obj.GetValue<string>('kind', ''), 'Kind should be interface');

      // Should have methods array with GetName and Speak
      Assert.IsNotNull(Obj.FindValue('methods'), 'Should have methods: ' + Obj.ToString);
      Methods := Obj.GetValue<TJSONArray>('methods');
      Assert.AreEqual(2, Methods.Count, 'Should have 2 methods');
      Assert.IsTrue(Obj.ToString.Contains('GetName'), 'Should contain GetName method');
      Assert.IsTrue(Obj.ToString.Contains('Speak'), 'Should contain Speak method');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.NoFile_SearchesAllParsed;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  // No file specified - should search all parsed files
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TDog', Obj.GetValue<string>('name'), 'Type name should be TDog');
      Assert.IsNotNull(Obj.Get('file'), 'Should have file field added');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetTypeDetailTests.NonExistent_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TFoo');
  Params.AddPair('file', 'Dog.pas');
  try
    Result := FTools.DoGetTypeDetail(Params);
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

procedure TDirectToolsGetTypeDetailTests.NonExistent_NoFile_RaisesException;
var
  Params: TJSONObject;
  Raised: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TFoo');
  // No file - should search all and raise if not found
  Raised := False;
  try
    FTools.DoGetTypeDetail(Params);
  except
    on E: Exception do
    begin
      Raised := True;
      Assert.Contains<string>(E.Message, 'not found', 'Exception should mention not found');
    end;
  end;
  Assert.IsTrue(Raised, 'Should raise exception for non-existent type when no file specified');
  Params.Free;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetTypeDetailTests);
end.
