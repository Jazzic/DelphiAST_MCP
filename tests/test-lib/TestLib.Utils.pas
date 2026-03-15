unit TestLib.Utils;

interface

uses
  TestLib.Types;

type
  TTestUtils = class
  class function DoubleValue(const AValue: Integer): Integer;
  class function CreateTestClass: TTestClass;
  end;

implementation

{ TTestUtils }

class function TTestUtils.DoubleValue(const AValue: Integer): Integer;
begin
  Result := AValue * 2;
end;

class function TTestUtils.CreateTestClass: TTestClass;
begin
  Result := TTestClass.Create;
  Result.Value := 42;
end;

end.
