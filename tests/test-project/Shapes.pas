unit Shapes;

interface

type
  TShape = class
  private
    FColor: string;
    procedure SetColor(const Value: string);
  public
    constructor Create(const AColor: string);
    function Area: Double; virtual; abstract;
    function Describe: string; virtual;
    property Color: string read FColor write SetColor;
  end;

  TCircle = class(TShape)
  private
    FRadius: Double;
  public
    constructor Create(const AColor: string; ARadius: Double);
    function Area: Double; override;
  end;

  TRectangle = class(TShape)
  private
    FWidth: Double;
    FHeight: Double;
  public
    constructor Create(const AColor: string; AWidth, AHeight: Double);
    function Area: Double; override;
  end;

implementation

constructor TShape.Create(const AColor: string);
begin
  inherited Create;
  FColor := AColor;
end;

procedure TShape.SetColor(const Value: string);
begin
  FColor := Value;
end;

function TShape.Describe: string;
begin
  Result := 'A ' + Color + ' shape with area ' + FloatToStr(Area);
end;

constructor TCircle.Create(const AColor: string; ARadius: Double);
begin
  inherited Create(AColor);
  FRadius := ARadius;
end;

function TCircle.Area: Double;
begin
  Result := 3.14159 * FRadius * FRadius;
end;

constructor TRectangle.Create(const AColor: string; AWidth, AHeight: Double);
begin
  inherited Create(AColor);
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TRectangle.Area: Double;
begin
  Result := FWidth * FHeight;
end;

end.
