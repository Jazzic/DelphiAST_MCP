unit AnimalRegistry;

interface

uses
  Animals, Dog, Cat;

type
  TAnimalRegistry = class
  private
    FAnimals: array of IAnimal;
    FCount: Integer;
    function GetAnimal(Index: Integer): IAnimal;
  public
    constructor Create;
    procedure RegisterAnimal(const Animal: IAnimal);
    function FindAnimal(const AName: string): IAnimal;
    function Count: Integer;
    property Animals[Index: Integer]: IAnimal read GetAnimal; default;
  end;

implementation

constructor TAnimalRegistry.Create;
begin
  inherited Create;
  FCount := 0;
end;

procedure TAnimalRegistry.RegisterAnimal(const Animal: IAnimal);
begin
  SetLength(FAnimals, FCount + 1);
  FAnimals[FCount] := Animal;
  Inc(FCount);
end;

function TAnimalRegistry.FindAnimal(const AName: string): IAnimal;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FCount - 1 do
  begin
    if FAnimals[I].GetName = AName then
    begin
      Result := FAnimals[I];
      Exit;
    end;
  end;
end;

function TAnimalRegistry.Count: Integer;
begin
  Result := FCount;
end;

function TAnimalRegistry.GetAnimal(Index: Integer): IAnimal;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FAnimals[Index]
  else
    Result := nil;
end;

end.
