unit Tests.FindUsages;

interface

uses
  DUnitX.TestFramework, System.JSON, System.SysUtils;

type
  [TestFixture]
  TFindUsagesTests = class
  public
    [Test]
    procedure FName_FoundInAnimals;
    [Test]
    procedure Speak_FoundAcrossFiles;
  end;

implementation

uses
  MCP.TestHelper;

procedure TFindUsagesTests.FName_FoundInAnimals;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  FileName: string;
begin
  Args := TJSONObject.Create;
  Args.AddPair('name', 'FName');
  try
    Result := TMCPTestHelper.CallTool('find_usages', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count >= 1, 'Should find at least 1 usage of FName');
      // At least one should be in Animals.pas
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr[I] is TJSONObject then
        begin
          Item := TJSONObject(Arr[I]);
          FileName := Item.GetValue<string>('file', '');
          if Pos('nimals.pas', LowerCase(FileName)) > 0 then
            Exit; // Found
        end;
      end;
      raise Exception.Create('Should find FName in Animals.pas');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

procedure TFindUsagesTests.Speak_FoundAcrossFiles;
var
  Args: TJSONObject;
  Result: TJSONValue;
  Arr: TJSONArray;
begin
  Args := TJSONObject.Create;
  Args.AddPair('name', 'Speak');
  try
    Result := TMCPTestHelper.CallTool('find_usages', Args);
    try
      Assert.IsNotNull(Result, 'Result is nil');
      Assert.IsTrue(Result is TJSONArray, 'Result should be a TJSONArray but was: ' + Result.ClassName);
      Arr := TJSONArray(Result);
      Assert.IsTrue(Arr.Count >= 3, 'Should find at least 3 Speak usages (TAnimal, TDog, TCat)');
    finally
      Result.Free;
    end;
  finally
    Args.Free;
  end;
end;

end.
