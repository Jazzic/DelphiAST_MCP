unit CouplingDemo;

interface

uses
  Animals, Dog;

type
  TCouplingDemo = class
  private
    FDog: TDog;
  public
    procedure Feed(const Animal: IAnimal);
    function CreateDog: TDog;
    procedure ProcessLocals;
    procedure DoCast;
  end;

implementation

procedure TCouplingDemo.Feed(const Animal: IAnimal);
var
  Kind: TAnimalKind;
begin
  Kind := akDog;
end;

function TCouplingDemo.CreateDog: TDog;
begin
  Result := TDog.Create('Rex', 'Labrador');
end;

procedure TCouplingDemo.ProcessLocals;
var
  Dog: TDog;
  Animal: IAnimal;
begin
  Dog := FDog;
  Animal := Dog as IAnimal;
end;

procedure TCouplingDemo.DoCast;
var
  Animal: IAnimal;
  Dog: TDog;
begin
  Animal := FDog as IAnimal;
  Dog := TDog(Animal);
end;

end.
