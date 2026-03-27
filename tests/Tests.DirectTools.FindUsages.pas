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
    [Test] procedure TAnimal_IncludesAncestorInDog;
    [Test] procedure TShape_IncludesAncestorsInShapes;
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
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

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

procedure TDirectToolsFindUsagesTests.TAnimal_IncludesAncestorInDog;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  FoundAncestor: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'TAnimal');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count > 0, 'Should find usages of TAnimal');

      // Check that at least one usage has context='ancestor'
      FoundAncestor := False;
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        if Item.GetValue<string>('context', '') = 'ancestor' then
        begin
          FoundAncestor := True;
          Break;
        end;
      end;
      Assert.IsTrue(FoundAncestor,
        'Should find at least one ancestor usage of TAnimal (e.g., TDog = class(TAnimal))');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsFindUsagesTests.TShape_IncludesAncestorsInShapes;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  I, AncestorCount: Integer;
  Item: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('name', 'TShape');
  try
    Result := FTools.DoFindUsages(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONArray, 'Result should be TJSONArray');
      Arr := TJSONArray(Result);

      // Count ancestor usages -- TCircle and TRectangle both inherit from TShape
      AncestorCount := 0;
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        if Item.GetValue<string>('context', '') = 'ancestor' then
          Inc(AncestorCount);
      end;
      Assert.IsTrue(AncestorCount >= 2,
        Format('Should find at least 2 ancestor usages of TShape (TCircle, TRectangle), found %d', [AncestorCount]));
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
