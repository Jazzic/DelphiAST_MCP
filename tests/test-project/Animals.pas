unit Animals;

interface

type
  TAnimalKind = (akDog, akCat, akBird);

  IAnimal = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetName: string;
    function Speak: string;
  end;

  TAnimal = class(TInterfacedObject, IAnimal)
  private
    FName: string;
    FKind: TAnimalKind;
  protected
    function GetName: string; virtual;
  public
    constructor Create(const AName: string; AKind: TAnimalKind);
    destructor Destroy; override;
    function Speak: string; virtual; abstract;
    property Name: string read GetName;
    property Kind: TAnimalKind read FKind;
  end;

implementation

constructor TAnimal.Create(const AName: string; AKind: TAnimalKind);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
end;

destructor TAnimal.Destroy;
begin
  inherited Destroy;
end;

function TAnimal.GetName: string;
begin
  Result := FName;
end;

end.
