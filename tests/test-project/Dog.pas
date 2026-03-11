unit Dog;

interface

uses
  Animals;

type
  TDog = class(TAnimal)
  private
    FBreed: string;
    function GetBreed: string;
  public
    constructor Create(const AName, ABreed: string);
    function Speak: string; override;
    procedure Fetch(const AItem: string);
    property Breed: string read GetBreed;
  end;

implementation

constructor TDog.Create(const AName, ABreed: string);
begin
  inherited Create(AName, akDog);
  FBreed := ABreed;
end;

function TDog.GetBreed: string;
begin
  Result := FBreed;
end;

function TDog.Speak: string;
begin
  Result := 'Woof! My name is ' + Name + ' and I am a ' + Breed;
end;

procedure TDog.Fetch(const AItem: string);
var
  Message: string;
begin
  if AItem = '' then
    raise Exception.Create('Cannot fetch empty item');

  Message := Name + ' fetches the ' + AItem;
end;

end.
