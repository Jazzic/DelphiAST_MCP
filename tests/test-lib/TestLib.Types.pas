unit TestLib.Types;

interface

type
  TTestEnum = (teFirst, teSecond, teThird);

  TTestRecord = record
    Name: string;
    Value: Integer;
  end;

  TTestClass = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
    function GetDouble: Integer;
  end;

implementation

{ TTestClass }

function TTestClass.GetDouble: Integer;
begin
  Result := FValue * 2;
end;

end.
