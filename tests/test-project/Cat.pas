unit Cat;

interface

uses
  Animals;

type
  TCat = class(TAnimal)
  private
    FIndoor: Boolean;
  public
    constructor Create(const AName: string; AIndoor: Boolean);
    function Speak: string; override;
    function IsIndoor: Boolean;
    property Indoor: Boolean read FIndoor;
  end;

implementation

constructor TCat.Create(const AName: string; AIndoor: Boolean);
begin
  inherited Create(AName, akCat);
  FIndoor := AIndoor;
end;

function TCat.Speak: string;
begin
  Result := 'Meow! My name is ' + Name;
end;

function TCat.IsIndoor: Boolean;
begin
  Result := FIndoor;
end;

end.
