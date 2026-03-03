unit AST.Parser;

interface

uses
  SysUtils, Classes, Generics.Collections, IOUtils,
  DelphiAST, DelphiAST.Classes, DelphiAST.Consts,
  SimpleParser.Lexer.Types;

type
  TCachedTree = record
    Node: TSyntaxNode;
    ModifiedAt: TDateTime;
  end;

  TSimpleIncludeHandler = class(TInterfacedObject, IIncludeHandler)
  private
    FRoots: TArray<string>;
  public
    constructor Create(const AProjectRoot: string); overload;
    constructor Create(const ARoots: TArray<string>); overload;
    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
  end;

  TASTParser = class
  private
    FRoots: TArray<string>;
    FCache: TDictionary<string, TCachedTree>;
    FIncludeHandler: IIncludeHandler;
    function GetProjectRoot: string;
  public
    constructor Create(const AProjectRoot: string); overload;
    constructor Create(const ARoots: TArray<string>); overload;
    destructor Destroy; override;

    function ListFiles(const NameFilter: string = ''): TArray<string>;
    function ParseFile(const AFileName: string): TSyntaxNode;
    procedure ParseAllFiles;
    function GetAllTrees: TArray<TPair<string, TSyntaxNode>>;
    procedure ClearCache;
    function ResolveFilePath(const AFileName: string): string;

    property ProjectRoot: string read GetProjectRoot;
  end;

implementation

{ TSimpleIncludeHandler }

constructor TSimpleIncludeHandler.Create(const AProjectRoot: string);
begin
  inherited Create;
  FRoots := TArray<string>.Create(AProjectRoot);
end;

constructor TSimpleIncludeHandler.Create(const ARoots: TArray<string>);
begin
  inherited Create;
  FRoots := Copy(ARoots);
end;

function TSimpleIncludeHandler.GetIncludeFileContent(
  const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  Dir, FullPath: string;
  I: Integer;
begin
  Result := False;
  Content := '';
  FileName := '';

  // Search parent directory first
  Dir := ExtractFilePath(ParentFileName);
  FullPath := TPath.Combine(Dir, IncludeName);
  if FileExists(FullPath) then
  begin
    FileName := FullPath;
    Content := TFile.ReadAllText(FullPath);
    Exit(True);
  end;

  // Then search all roots
  for I := 0 to High(FRoots) do
  begin
    FullPath := TPath.Combine(FRoots[I], IncludeName);
    if FileExists(FullPath) then
    begin
      FileName := FullPath;
      Content := TFile.ReadAllText(FullPath);
      Exit(True);
    end;
  end;
end;

{ TASTParser }

function TASTParser.GetProjectRoot: string;
begin
  Result := FRoots[0];
end;

constructor TASTParser.Create(const AProjectRoot: string);
begin
  Create(TArray<string>.Create(AProjectRoot));
end;

constructor TASTParser.Create(const ARoots: TArray<string>);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FRoots, Length(ARoots));
  for I := 0 to High(ARoots) do
    FRoots[I] := IncludeTrailingPathDelimiter(ARoots[I]);
  FCache := TDictionary<string, TCachedTree>.Create;
  FIncludeHandler := TSimpleIncludeHandler.Create(FRoots);
end;

destructor TASTParser.Destroy;
var
  Entry: TCachedTree;
begin
  FIncludeHandler := nil;
  for Entry in FCache.Values do
    Entry.Node.Free;
  FCache.Free;
  inherited;
end;

function TASTParser.ListFiles(const NameFilter: string): TArray<string>;
var
  Files: TStringList;
  AllFiles: TArray<string>;
  F, RelPath, LowerFilter, Root, Ext: string;
  I: Integer;
begin
  Files := TStringList.Create;
  try
    Files.Sorted := True;
    Files.Duplicates := dupIgnore;
    LowerFilter := LowerCase(NameFilter);

    for I := 0 to High(FRoots) do
    begin
      Root := FRoots[I];
      if not DirectoryExists(Root) then
        Continue;

      AllFiles := TDirectory.GetFiles(Root, '*.*',
        TSearchOption.soAllDirectories);

      for F in AllFiles do
      begin
        Ext := LowerCase(ExtractFileExt(F));
        if (Ext <> '.pas') and (Ext <> '.dpr') and (Ext <> '.dpk') then
          Continue;

        RelPath := F;
        if RelPath.StartsWith(Root, True) then
          RelPath := RelPath.Substring(Length(Root));

        if (LowerFilter = '') or
           (Pos(LowerFilter, LowerCase(ExtractFileName(F))) > 0) then
          Files.Add(RelPath);
      end;
    end;

    Result := Files.ToStringArray;
  finally
    Files.Free;
  end;
end;

function TASTParser.ResolveFilePath(const AFileName: string): string;
var
  I: Integer;
  FullPath: string;
begin
  if not TPath.IsRelativePath(AFileName) then
    Exit(AFileName);

  // Check each root for file existence
  for I := 0 to High(FRoots) do
  begin
    FullPath := TPath.Combine(FRoots[I], AFileName);
    if FileExists(FullPath) then
      Exit(FullPath);
  end;

  // Fall back to first root
  Result := TPath.Combine(FRoots[0], AFileName);
end;

function TASTParser.ParseFile(const AFileName: string): TSyntaxNode;
var
  FullPath, Key: string;
  Entry: TCachedTree;
  FileTime: TDateTime;
begin
  FullPath := ResolveFilePath(AFileName);
  Key := LowerCase(FullPath);

  if FCache.TryGetValue(Key, Entry) then
  begin
    FileTime := TFile.GetLastWriteTime(FullPath);
    if FileTime <= Entry.ModifiedAt then
      Exit(Entry.Node);
    // File changed — evict old entry
    Entry.Node.Free;
    FCache.Remove(Key);
  end;

  if not FileExists(FullPath) then
    raise Exception.CreateFmt('File not found: %s', [FullPath]);

  Entry.Node := TPasSyntaxTreeBuilder.Run(FullPath, False, FIncludeHandler);
  Entry.ModifiedAt := TFile.GetLastWriteTime(FullPath);
  FCache.Add(Key, Entry);
  Result := Entry.Node;
end;

procedure TASTParser.ParseAllFiles;
var
  Files: TArray<string>;
  F: string;
  Parsed, Failed: Integer;
begin
  Files := ListFiles('');
  Parsed := 0;
  Failed := 0;
  for F in Files do
  begin
    try
      ParseFile(F);
      Inc(Parsed);
    except
      on E: Exception do
      begin
        Inc(Failed);
        WriteLn(ErrOutput, '[delphi-ast] Failed to parse ' + F + ': ' + E.Message);
      end;
    end;
  end;
  WriteLn(ErrOutput, '[delphi-ast] Eager parse complete: ' +
    IntToStr(Parsed) + ' parsed, ' + IntToStr(Failed) + ' failed');
end;

function TASTParser.GetAllTrees: TArray<TPair<string, TSyntaxNode>>;
var
  Pair: TPair<string, TCachedTree>;
  List: TList<TPair<string, TSyntaxNode>>;
begin
  List := TList<TPair<string, TSyntaxNode>>.Create;
  try
    for Pair in FCache do
      List.Add(TPair<string, TSyntaxNode>.Create(Pair.Key, Pair.Value.Node));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TASTParser.ClearCache;
var
  Entry: TCachedTree;
begin
  for Entry in FCache.Values do
    Entry.Node.Free;
  FCache.Clear;
end;

end.
