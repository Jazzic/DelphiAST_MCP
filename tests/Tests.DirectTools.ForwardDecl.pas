unit Tests.DirectTools.ForwardDecl;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsForwardDeclTests = class
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

    // get_type_detail tests — forward-declared types must return full detail
    [Test] procedure TDevice_GetTypeDetail_ReturnsFullDecl;
    [Test] procedure TSerialDevice_GetTypeDetail_ReturnsFullDecl;
    [Test] procedure TAlpha_GetTypeDetail_ReturnsFullDecl;
    [Test] procedure TBeta_GetTypeDetail_ReturnsFullDecl;

    // resolve_inheritance tests — chains must not stop at forward stubs
    [Test] procedure TDevice_ResolveInheritance_ReachesAncestor;
    [Test] procedure TConcreteSerial_ResolveInheritance_FullChain;
    [Test] procedure TSimpleDevice_ResolveInheritance_ForwardAncestorResolved;
    [Test] procedure TAlpha_ResolveInheritance_ReachesAncestor;

    // Control group — non-forward types must continue to work
    [Test] procedure TStandaloneClass_ResolveInheritance_Unaffected;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsForwardDeclTests }

procedure TDirectToolsForwardDeclTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsForwardDeclTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

// ---------------------------------------------------------------------------
// get_type_detail tests
// ---------------------------------------------------------------------------

procedure TDirectToolsForwardDeclTests.TDevice_GetTypeDetail_ReturnsFullDecl;
// TDevice has a forward decl at line 38 and the real decl at line 49.
// Must return line=49, kind=class, ancestors includes TComponent.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Line: Integer;
  Kind: string;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDevice');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Line := Obj.GetValue<Integer>('line');
      Assert.AreEqual(49, Line,
        Format('TDevice should resolve to full decl at line 49, got line %d', [Line]));

      Kind := Obj.GetValue<string>('kind', '');
      Assert.AreEqual('class', Kind, 'kind should be "class"');

      Assert.IsNotNull(Obj.Get('ancestors'), 'Full decl must have ancestors');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TSerialDevice_GetTypeDetail_ReturnsFullDecl;
// TSerialDevice: forward at line 77, real at line 88. Must return line=88.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Line: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TSerialDevice');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Line := Obj.GetValue<Integer>('line');
      Assert.AreEqual(88, Line,
        Format('TSerialDevice should resolve to full decl at line 88, got line %d', [Line]));
      Assert.IsNotNull(Obj.Get('ancestors'), 'Full decl must have ancestors');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TAlpha_GetTypeDetail_ReturnsFullDecl;
// TAlpha: forward at line 162, real at line 165. Must return line=165.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Line: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAlpha');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Line := Obj.GetValue<Integer>('line');
      Assert.AreEqual(165, Line,
        Format('TAlpha should resolve to full decl at line 165, got line %d', [Line]));
      Assert.IsNotNull(Obj.Get('ancestors'), 'Full decl must have ancestors');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TBeta_GetTypeDetail_ReturnsFullDecl;
// TBeta: forward at line 163, real at line 172. Must return line=172.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Line: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TBeta');
  try
    Result := FTools.DoGetTypeDetail(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Line := Obj.GetValue<Integer>('line');
      Assert.AreEqual(172, Line,
        Format('TBeta should resolve to full decl at line 172, got line %d', [Line]));
      Assert.IsNotNull(Obj.Get('ancestors'), 'Full decl must have ancestors');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

// ---------------------------------------------------------------------------
// resolve_inheritance tests
// ---------------------------------------------------------------------------

procedure TDirectToolsForwardDeclTests.TDevice_ResolveInheritance_ReachesAncestor;
// TDevice itself is forward-declared. Chain must include TComponent (unresolved)
// and complete must be False.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
  FirstItem: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDevice');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Assert.IsTrue(Chain.Count >= 2,
        Format('TDevice chain should have >= 2 items, got %d', [Chain.Count]));

      // First item must be TDevice at the FULL declaration line (49)
      FirstItem := Chain.Items[0] as TJSONObject;
      Assert.AreEqual(49, FirstItem.GetValue<Integer>('line'),
        'First chain item must be full TDevice decl at line 49');

      // complete must be False because TComponent is external
      Complete := Obj.GetValue<Boolean>('complete');
      Assert.IsFalse(Complete, 'complete should be False (TComponent is not in project)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TConcreteSerial_ResolveInheritance_FullChain;
// Expected chain: TConcreteSerial -> TSerialDevice -> TDevice -> TComponent (unresolved)
// Chain depth must be >= 4 (or at least 3 resolved + 1 unresolved).
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
  SecondItem: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TConcreteSerial');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      // Must have at least TConcreteSerial + TSerialDevice + TDevice + TComponent
      Assert.IsTrue(Chain.Count >= 4,
        Format('TConcreteSerial chain should have >= 4 items, got %d', [Chain.Count]));

      // Second item must be TSerialDevice at full decl line 88 (not forward line 77)
      SecondItem := Chain.Items[1] as TJSONObject;
      Assert.AreEqual('TSerialDevice', SecondItem.GetValue<string>('name'),
        'Second chain item should be TSerialDevice');
      Assert.AreEqual(88, SecondItem.GetValue<Integer>('line'),
        'TSerialDevice in chain must be at full decl line 88, not forward line 77');

      Complete := Obj.GetValue<Boolean>('complete');
      Assert.IsFalse(Complete, 'complete should be False (TComponent is external)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TSimpleDevice_ResolveInheritance_ForwardAncestorResolved;
// TSimpleDevice has no forward decl, but its ancestor TDevice does.
// Chain: TSimpleDevice -> TDevice (full, line 49) -> TComponent (unresolved).
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
  SecondItem: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TSimpleDevice');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Assert.IsTrue(Chain.Count >= 3,
        Format('TSimpleDevice chain should have >= 3 items, got %d', [Chain.Count]));

      // Second item must be TDevice at full decl line 49 (not forward line 38)
      SecondItem := Chain.Items[1] as TJSONObject;
      Assert.AreEqual('TDevice', SecondItem.GetValue<string>('name'),
        'Second chain item should be TDevice');
      Assert.AreEqual(49, SecondItem.GetValue<Integer>('line'),
        'TDevice in chain must be at full decl line 49, not forward line 38');

      Complete := Obj.GetValue<Boolean>('complete');
      Assert.IsFalse(Complete, 'complete should be False (TComponent is external)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TAlpha_ResolveInheritance_ReachesAncestor;
// TAlpha is forward-declared. Chain: TAlpha (line 165) -> TComponent (unresolved).
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
  FirstItem: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAlpha');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Assert.IsTrue(Chain.Count >= 2,
        Format('TAlpha chain should have >= 2 items, got %d', [Chain.Count]));

      // First item must be TAlpha at full decl line 165 (not forward line 162)
      FirstItem := Chain.Items[0] as TJSONObject;
      Assert.AreEqual(165, FirstItem.GetValue<Integer>('line'),
        'TAlpha must be at full decl line 165, not forward line 162');

      Complete := Obj.GetValue<Boolean>('complete');
      Assert.IsFalse(Complete, 'complete should be False (TComponent is external)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsForwardDeclTests.TStandaloneClass_ResolveInheritance_Unaffected;
// TStandaloneClass has no forward decl and no forward-declared ancestors.
// Regression test: the fix must not break types that were already working.
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Chain: TJSONArray;
  Complete: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TStandaloneClass');
  try
    Result := FTools.DoResolveInheritance(Params);
    try
      Obj := Result as TJSONObject;
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Chain := Obj.GetValue<TJSONArray>('chain');
      Assert.IsTrue(Chain.Count >= 2,
        Format('TStandaloneClass chain should have >= 2 items, got %d', [Chain.Count]));

      Complete := Obj.GetValue<Boolean>('complete');
      Assert.IsFalse(Complete, 'complete should be False (TPersistent is external)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsForwardDeclTests);
end.
