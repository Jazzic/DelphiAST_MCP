unit Tests.DirectTools.GetCallGraph;

interface

uses
  DUnitX.TestFramework, System.JSON, AST.Parser, MCP.Tools;

type
  [TestFixture]
  TDirectToolsGetCallGraphTests = class
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

    // get_call_graph tests - limited due to known issues with this tool
    [Test] procedure ParserWorks;
    [Test] procedure NonExistentMethod_ReturnsError;
    [Test] procedure TDogFetch_ResolvesCallees;
    [Test] procedure TDogCreate_NoDuplicates;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

{ TDirectToolsGetCallGraphTests }

procedure TDirectToolsGetCallGraphTests.SetupFixture;
begin
  FProjectPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\tests\test-project');
  FParser := TASTParser.Create(FProjectPath);

  FTimeout := GetTickCount + 10000;
  while not FParser.IsReady and (GetTickCount < FTimeout) do
    Sleep(50);

  Assert.IsTrue(FParser.IsReady, 'Parser should be ready within timeout');

  FTools := TMCPTools.Create(FParser);
end;

procedure TDirectToolsGetCallGraphTests.TearDownFixture;
begin
  FreeAndNil(FTools);
  FreeAndNil(FParser);
end;

procedure TDirectToolsGetCallGraphTests.ParserWorks;
begin
  // Just verify parser is configured and ready
  Assert.IsTrue(FParser.IsConfigured, 'Parser should be configured');
  Assert.IsTrue(FParser.IsReady, 'Parser should be ready');
end;

procedure TDirectToolsGetCallGraphTests.NonExistentMethod_ReturnsError;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TNoSuch.Missing');
  try
    Result := FTools.DoGetCallGraph(Params);
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

procedure TDirectToolsGetCallGraphTests.TDogFetch_ResolvesCallees;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Calls: TJSONArray;
  I: Integer;
  CallItem: TJSONObject;
  HasExceptionCreate: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Fetch');
  try
    Result := FTools.DoGetCallGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Obj := TJSONObject(Result);

      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);
      Calls := Obj.GetValue<TJSONArray>('calls');
      Assert.IsTrue(Calls.Count > 0, 'TDog.Fetch should have calls (Exception.Create, Name)');

      // Verify Exception.Create is in the list (likely unresolved, since it is RTL)
      HasExceptionCreate := False;
      for I := 0 to Calls.Count - 1 do
      begin
        CallItem := Calls.Items[I] as TJSONObject;
        if Pos('Exception.Create', CallItem.GetValue<string>('name', '')) > 0 then
        begin
          HasExceptionCreate := True;
          Break;
        end;
      end;
      Assert.IsTrue(HasExceptionCreate, 'Should find Exception.Create call');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDirectToolsGetCallGraphTests.TDogCreate_NoDuplicates;
var
  Params: TJSONObject;
  Result: TJSONValue;
  Obj: TJSONObject;
  Calls: TJSONArray;
  I, J: Integer;
  CallItemI, CallItemJ: TJSONObject;
  NameI, NameJ: string;
  LineI, LineJ: Integer;
  HasDuplicate: Boolean;
begin
  Params := TJSONObject.Create;
  Params.AddPair('method_name', 'TDog.Create');
  try
    Result := FTools.DoGetCallGraph(Params);
    try
      Assert.IsNotNull(Result, 'Result should not be null');
      Obj := TJSONObject(Result);
      Assert.IsNull(Obj.Get('error'), 'Should not have error: ' + Obj.ToString);

      Calls := Obj.GetValue<TJSONArray>('calls');
      // Verify no duplicate entries (same name AND same line)
      HasDuplicate := False;
      for I := 0 to Calls.Count - 2 do
      begin
        CallItemI := Calls.Items[I] as TJSONObject;
        NameI := CallItemI.GetValue<string>('name', '');
        LineI := CallItemI.GetValue<Integer>('line', 0);
        for J := I + 1 to Calls.Count - 1 do
        begin
          CallItemJ := Calls.Items[J] as TJSONObject;
          NameJ := CallItemJ.GetValue<string>('name', '');
          LineJ := CallItemJ.GetValue<Integer>('line', 0);
          if (NameI = NameJ) and (LineI = LineJ) then
          begin
            HasDuplicate := True;
            Break;
          end;
        end;
        if HasDuplicate then
          Break;
      end;
      Assert.IsFalse(HasDuplicate,
        'Call list should not contain duplicate entries (same name and line)');
    finally
      Result.Free;
    end;
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDirectToolsGetCallGraphTests);
end.
