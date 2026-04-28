unit ProceduralUnit;

interface

uses
  Animals, Dog;

// Standalone procedures — no class, no TFoo. prefix anywhere
procedure RegisterDog(const Animal: IAnimal);
function  CreateDefaultDog: TDog;
procedure ProcessAnimal(const Animal: IAnimal);

implementation

procedure RegisterDog(const Animal: IAnimal);
var
  D: TDog;
begin
  D := Animal as TDog;
end;

function CreateDefaultDog: TDog;
begin
  Result := TDog.Create('Default', 'Mixed');
end;

procedure ProcessAnimal(const Animal: IAnimal);
var
  D: TDog;
begin
  D := TDog.Create('Temp', 'Mix');
  D.Free;
end;

end.
