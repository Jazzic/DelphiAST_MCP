unit TestForwardDecl;

// ============================================================================
// Bug reproduction file for delphi-ast resolve_inheritance / get_type_detail
//
// Root cause: Forward declarations (TFoo = class;) are indexed as the primary
// type entry, shadowing the actual class declaration that follows. This causes
// get_type_detail to return stubs and resolve_inheritance to stop early.
//
// HOW TO TEST:
//   1. set_project pointing to this file's directory (or parent)
//   2. Run the tool calls listed below each scenario
//   3. Compare actual vs expected results
// ============================================================================

interface

uses
  Classes, SysUtils;

type
  // =========================================================================
  // SCENARIO 1: Simple forward declaration
  //
  // The most common pattern. Forward decl needed because TWorkerThread
  // references TDevice before it is fully declared.
  //
  // Test calls:
  //   get_type_detail(type_name: "TDevice")
  //     Expected: kind=class, ancestors=[TComponent], sections with FName etc.
  //     Bug:      stub {name, line:29, file} — picks up forward at line 29
  //
  //   resolve_inheritance(type_name: "TDevice")
  //     Expected: TDevice -> TComponent (unresolved)
  //     Bug:      depth 1, only TDevice stub, complete=true
  // =========================================================================

  TDevice = class;

  TWorkerThread = class(TThread)
  private
    FOwner: TDevice;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TDevice);
  end;

  TDevice = class(TComponent)
  private
    FName: string;
    FThread: TWorkerThread;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure Stop; virtual;
    property DeviceName: string read FName write FName;
  end;

  // =========================================================================
  // SCENARIO 2: Forward declaration in a deeper hierarchy
  //
  // Tests that resolve_inheritance correctly walks through a forward-declared
  // intermediate class.
  //
  // Test calls:
  //   get_type_detail(type_name: "TSerialDevice")
  //     Expected: kind=class, ancestors=[TDevice], sections with FPort etc.
  //     Bug:      stub — if TSerialDevice also has a forward decl
  //
  //   resolve_inheritance(type_name: "TConcreteSerial")
  //     Expected: TConcreteSerial -> TSerialDevice -> TDevice -> TComponent
  //     Bug:      Stops at first forward-declared ancestor
  // =========================================================================

  TSerialDevice = class;

  TSerialMonitor = class(TThread)
  private
    FDevice: TSerialDevice;
  protected
    procedure Execute; override;
  public
    constructor Create(ADevice: TSerialDevice);
  end;

  TSerialDevice = class(TDevice)
  private
    FPort: Integer;
    FBaudRate: Integer;
    FMonitor: TSerialMonitor;
  public
    procedure Start; override;
    procedure Stop; override;
    property Port: Integer read FPort write FPort;
    property BaudRate: Integer read FBaudRate write FBaudRate;
  end;

  // No forward declaration — should always work
  TConcreteSerial = class(TSerialDevice)
  private
    FProtocol: string;
  public
    procedure Start; override;
    property Protocol: string read FProtocol write FProtocol;
  end;

  // =========================================================================
  // SCENARIO 3: No forward declarations (control group)
  //
  // These types should always work correctly with both tools.
  //
  // Test calls:
  //   get_type_detail(type_name: "TSimpleDevice")
  //     Expected: full detail with kind, ancestors, sections
  //
  //   resolve_inheritance(type_name: "TSimpleDevice")
  //     Expected: TSimpleDevice -> TDevice -> TComponent (unresolved)
  //     Note: Will still stop at TDevice due to Scenario 1's forward decl!
  //
  //   resolve_inheritance(type_name: "TStandaloneClass")
  //     Expected: TStandaloneClass -> TObject (unresolved)
  //     Should work fully — no forward-declared types in the chain.
  // =========================================================================

  TSimpleDevice = class(TDevice)
  private
    FValue: Double;
  public
    procedure Start; override;
    property Value: Double read FValue;
  end;

  TStandaloneClass = class(TPersistent)
  private
    FData: string;
  public
    procedure Assign(Source: TPersistent); override;
    property Data: string read FData write FData;
  end;

  // =========================================================================
  // SCENARIO 4: Multiple forward declarations in same type section
  //
  // Both TAlpha and TBeta are forward-declared and reference each other.
  //
  // Test calls:
  //   get_type_detail(type_name: "TAlpha")
  //     Expected: kind=class, ancestors=[TComponent], sections with FBeta
  //     Bug:      stub at forward line
  //
  //   get_type_detail(type_name: "TBeta")
  //     Expected: kind=class, ancestors=[TComponent], sections with FAlpha
  //     Bug:      stub at forward line
  //
  //   resolve_inheritance(type_name: "TAlpha")
  //     Expected: TAlpha -> TComponent (unresolved)
  //     Bug:      depth 1, stub only
  // =========================================================================

  TAlpha = class;
  TBeta = class;

  TAlpha = class(TComponent)
  private
    FBeta: TBeta;
  public
    property Beta: TBeta read FBeta write FBeta;
  end;

  TBeta = class(TComponent)
  private
    FAlpha: TAlpha;
  public
    property Alpha: TAlpha read FAlpha write FAlpha;
  end;

  // =========================================================================
  // SCENARIO 5: Forward-declared type as ancestor
  //
  // TDevice (from Scenario 1) is forward-declared. Any type that inherits
  // from TDevice will have its resolve_inheritance chain broken at TDevice,
  // even if the child type itself has no forward declaration.
  //
  // Test calls:
  //   resolve_inheritance(type_name: "TSimpleDevice")
  //     Expected: TSimpleDevice -> TDevice -> TComponent (unresolved)
  //     Bug:      TSimpleDevice (full) -> TDevice (stub, line of forward decl)
  //               depth 2, complete=true (should be false)
  //
  //   This is Variant B of the bug — the queried type is fine, but an
  //   ancestor is forward-declared, stopping the chain.
  // =========================================================================

implementation

{ TWorkerThread }

constructor TWorkerThread.Create(AOwner: TDevice);
begin
  inherited Create(True);
  FOwner := AOwner;
end;

procedure TWorkerThread.Execute;
begin
  // worker loop
end;

{ TDevice }

constructor TDevice.Create(AOwner: TComponent);
begin
  inherited;
  FName := '';
  FThread := nil;
end;

destructor TDevice.Destroy;
begin
  FThread.Free;
  inherited;
end;

procedure TDevice.Start;
begin
  FThread := TWorkerThread.Create(Self);
  FThread.Start;
end;

procedure TDevice.Stop;
begin
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

{ TSerialMonitor }

constructor TSerialMonitor.Create(ADevice: TSerialDevice);
begin
  inherited Create(True);
  FDevice := ADevice;
end;

procedure TSerialMonitor.Execute;
begin
  // serial monitoring loop
end;

{ TSerialDevice }

procedure TSerialDevice.Start;
begin
  inherited;
  FMonitor := TSerialMonitor.Create(Self);
  FMonitor.Start;
end;

procedure TSerialDevice.Stop;
begin
  if Assigned(FMonitor) then
  begin
    FMonitor.Terminate;
    FMonitor.WaitFor;
    FreeAndNil(FMonitor);
  end;
  inherited;
end;

{ TConcreteSerial }

procedure TConcreteSerial.Start;
begin
  inherited;
  // protocol-specific init
end;

{ TSimpleDevice }

procedure TSimpleDevice.Start;
begin
  inherited;
  FValue := 0.0;
end;

{ TStandaloneClass }

procedure TStandaloneClass.Assign(Source: TPersistent);
begin
  if Source is TStandaloneClass then
    FData := TStandaloneClass(Source).FData
  else
    inherited;
end;

end.
