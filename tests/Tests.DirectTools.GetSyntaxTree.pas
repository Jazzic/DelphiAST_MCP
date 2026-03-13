unit Tests.DirectTools.GetSyntaxTree;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetSyntaxTreeTests = class
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

    // get_syntax_tree tests
    [Test] procedure Animals_RootNode;
    [Test] procedure Animals_FullTree;
    [Test] procedure Animals_PathInterface;
    [Test] procedure Dog_PathInterfaceTypes;
    [Test] procedure InvalidPath_ReturnsError;
    [Test] procedure MaxDepth2_LimitsChildren;
    [Test] procedure Shapes_HasThreeClasses;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetSyntaxTreeTests }

procedure TDirectToolsGetSyntaxTreeTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while FParser.IsParsing and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsFalse(FParser.IsParsing, 'Parser should have finished within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetSyntaxTreeTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetSyntaxTreeTests.Animals_RootNode;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  Params.AddPair('max_depth', 1);
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
      Assert.IsNotNull(Obj.Get('t'), 'Should have node type');
      Assert.IsNotNull(Obj.Get('children_count'), 'Should have children_count at depth 1');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.Animals_FullTree;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  Params.AddPair('max_depth', 0);
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.Animals_PathInterface;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  Params.AddPair('path', 'interface');
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.Dog_PathInterfaceTypes;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Dog.pas');
  Params.AddPair('path', 'interface');
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.InvalidPath_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Animals.pas');
  Params.AddPair('path', 'nonexistent');
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNotNull(Obj.Get('error'), 'Should have error for invalid path');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.MaxDepth2_LimitsChildren;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Shapes.pas');
  Params.AddPair('max_depth', 2);
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetSyntaxTreeTests.Shapes_HasThreeClasses;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('file', 'Shapes.pas');
  Params.AddPair('max_depth', 0);
  try
    Result := FTools.DoGetSyntaxTree(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Assert.IsTrue(Result is TJSONObject, 'Result should be TJSONObject');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetSyntaxTreeTests);
end.
