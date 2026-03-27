unit Tests.DirectTools.ResolveInheritance;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsResolveInheritanceTests = class
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

    // resolve_inheritance tests
    [Test] procedure TDog_Found;
    [Test] procedure TCircle_Found;
    [Test] procedure TAnimalRegistry_Found;
    [Test] procedure TAnimal_Found;
    [Test] procedure NonExistent_ReturnsError;
    [Test] procedure MaxDepth_Limits;
    [Test] procedure TDog_ChainHasDepthAtLeast2;
    [Test] procedure TCircle_ChainIncludesTShape;
    [Test] procedure TAnimalRegistry_CompleteFalse;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsResolveInheritanceTests }

procedure TDirectToolsResolveInheritanceTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsResolveInheritanceTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsResolveInheritanceTests.TDog_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TDog', Obj.GetValue<string>('type_name'), 'Type name should be TDog');
      Assert.IsNotNull(Obj.Get('chain'), 'Should have chain');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TCircle_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TCircle');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('chain'), 'Should have chain');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TAnimalRegistry_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimalRegistry');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('chain'), 'Should have chain');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TAnimal_Found;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimal');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('chain'), 'Should have chain');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.NonExistent_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TFoo');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNotNull(Obj.Get('error'), 'Should have error for non-existent type');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.MaxDepth_Limits;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  Params.AddPair('max_depth', 1);
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.IsNotNull(Obj.Get('depth'), 'Should have depth');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TDog_ChainHasDepthAtLeast2;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Depth: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := TJSONObject(Result);
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Depth := Obj.GetValue<Integer>('depth');

      // TDog -> TAnimal -> ... so chain depth should be >= 2
      Assert.IsTrue(Depth >= 2,
        Format('TDog chain depth should be >= 2, was %d', [Depth]));

      // Second item should be TAnimal
      Assert.AreEqual('TAnimal',
        (Chain.Items[1] as TJSONObject).GetValue<string>('name'),
        'Second chain item should be TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TCircle_ChainIncludesTShape;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  I: Integer;
  FoundTShape: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TCircle');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := TJSONObject(Result);
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');

      // Chain should include TShape somewhere
      FoundTShape := False;
      for I := 0 to Chain.Count - 1 do
      begin
        if (Chain.Items[I] as TJSONObject).GetValue<string>('name', '') = 'TShape' then
        begin
          FoundTShape := True;
          Break;
        end;
      end;
      Assert.IsTrue(FoundTShape, 'TCircle chain should include TShape');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsResolveInheritanceTests.TAnimalRegistry_CompleteFalse;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimalRegistry');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := TJSONObject(Result);
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Complete := Obj.GetValue<Boolean>('complete');

      // TAnimalRegistry has no explicit ancestor -- it implicitly inherits TObject
      // Chain should have at least 2 items (TAnimalRegistry + TObject stub)
      Assert.IsTrue(Chain.Count >= 2,
        Format('Chain should have >= 2 items for implicit TObject, had %d', [Chain.Count]));

      // complete should be false since TObject is unresolved
      Assert.IsFalse(Complete, 'complete should be False (TObject is not in project)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsResolveInheritanceTests);
end.
