unit Tests.DirectTools.FindDescendants;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsFindDescendantsTests = class
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

    // find_descendants tests
    [Test] procedure TAnimal_HasDirectChildren;
    [Test] procedure TShape_HasDirectChildren;
    [Test] procedure IAnimal_TransitivelyFindsImplementors;
    [Test] procedure IAnimal_DirectOnly;
    [Test] procedure TDog_NoDescendants;
    [Test] procedure NonExistent_ReturnsEmpty;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsFindDescendantsTests }

procedure TDirectToolsFindDescendantsTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsFindDescendantsTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsFindDescendantsTests.TAnimal_HasDirectChildren;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  FoundDog, FoundCat: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TAnimal');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Assert.AreEqual('TAnimal', Obj.GetValue<string>('type_name'), 'Type name should be TAnimal');
      Assert.IsNotNull(Obj.Get('descendants'), 'Should have descendants');

      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // Should find TDog and TCat
      FoundDog := False;
      FoundCat := False;
      for I := 0 to Descendants.Count - 1 do
      begin
        if Descendants[I].GetValue<string>('name') = 'TDog' then
          FoundDog := True;
        if Descendants[I].GetValue<string>('name') = 'TCat' then
          FoundCat := True;
      end;
      Assert.IsTrue(FoundDog, 'Should find TDog as descendant of TAnimal');
      Assert.IsTrue(FoundCat, 'Should find TCat as descendant of TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.TShape_HasDirectChildren;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  FoundCircle, FoundRectangle: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TShape');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      FoundCircle := False;
      FoundRectangle := False;
      for I := 0 to Descendants.Count - 1 do
      begin
        if Descendants[I].GetValue<string>('name') = 'TCircle' then
          FoundCircle := True;
        if Descendants[I].GetValue<string>('name') = 'TRectangle' then
          FoundRectangle := True;
      end;
      Assert.IsTrue(FoundCircle, 'Should find TCircle as descendant of TShape');
      Assert.IsTrue(FoundRectangle, 'Should find TRectangle as descendant of TShape');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.IAnimal_TransitivelyFindsImplementors;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  FoundAnimal, FoundDog, FoundCat: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'IAnimal');
  // No max_depth = unlimited (default 0)
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // Should find TAnimal (implements directly) and TDog/TCat (transitively)
      FoundAnimal := False;
      FoundDog := False;
      FoundCat := False;
      for I := 0 to Descendants.Count - 1 do
      begin
        if Descendants[I].GetValue<string>('name') = 'TAnimal' then
          FoundAnimal := True;
        if Descendants[I].GetValue<string>('name') = 'TDog' then
          FoundDog := True;
        if Descendants[I].GetValue<string>('name') = 'TCat' then
          FoundCat := True;
      end;
      Assert.IsTrue(FoundAnimal, 'Should find TAnimal as implementor of IAnimal');
      Assert.IsTrue(FoundDog, 'Should find TDog transitively through TAnimal');
      Assert.IsTrue(FoundCat, 'Should find TCat transitively through TAnimal');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.IAnimal_DirectOnly;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
  FoundAnimal, FoundDog, FoundCat: Boolean;
  I: Integer;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'IAnimal');
  Params.AddPair('max_depth', 1);
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');

      // With max_depth=1, should only find TAnimal (direct implementor)
      FoundAnimal := False;
      FoundDog := False;
      FoundCat := False;
      for I := 0 to Descendants.Count - 1 do
      begin
        if Descendants[I].GetValue<string>('name') = 'TAnimal' then
          FoundAnimal := True;
        if Descendants[I].GetValue<string>('name') = 'TDog' then
          FoundDog := True;
        if Descendants[I].GetValue<string>('name') = 'TCat' then
          FoundCat := True;
      end;
      Assert.IsTrue(FoundAnimal, 'Should find TAnimal as direct implementor of IAnimal');
      Assert.IsFalse(FoundDog, 'Should NOT find TDog with max_depth=1');
      Assert.IsFalse(FoundCat, 'Should NOT find TCat with max_depth=1');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.TDog_NoDescendants;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TDog');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');
      Assert.AreEqual(0, Descendants.Count, 'TDog should have no descendants');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindDescendantsTests.NonExistent_ReturnsEmpty;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Descendants: TJSONArray;
begin
  Params := TJSONObject.Create;
  Params.AddPair('type_name', 'TNonExistentType');
  try
    Result := FTools.DoFindDescendants(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      // Non-existent should return empty, not an error
      Assert.IsNull(Obj.Get('error'), 'Should not have error for non-existent type');
      Descendants := Obj.GetValue<TJSONArray>('descendants');
      Assert.IsNotNull(Descendants, 'Descendants should be an array');
      Assert.AreEqual(0, Descendants.Count, 'Non-existent type should have no descendants');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsFindDescendantsTests);
end.
