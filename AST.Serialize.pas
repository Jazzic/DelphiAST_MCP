unit AST.Serialize;

interface

uses
  SysUtils, Classes, Generics.Collections,
  DelphiAST.Consts, DelphiAST.Classes;

type
  TNodeClass = (ncSyntax, ncCompound, ncValued, ncComment);

  TFullASTSerializer = class
  strict private
    FStream: TStream;
    FStringList: TStringList;
    FStringTable: TDictionary<string, Integer>;

    function ReadNumber(var Num: Cardinal): Boolean;
    function ReadString(var Str: string): Boolean;
    function ReadNode(var Node: TSyntaxNode): Boolean;
    function WriteNumber(Num: Cardinal): Boolean;
    function WriteString(const S: string): Boolean;
    function WriteNode(Node: TSyntaxNode): Boolean;
    function CheckSignature: Boolean;
    function CheckVersion: Boolean;
    function CreateNode(AClass: TNodeClass; AType: TSyntaxNodeType): TSyntaxNode;
  public
    class function WriteToStream(Stream: TStream; Root: TSyntaxNode;
      ModifiedAt: TDateTime; const SourcePath: string): Boolean;
    class function ReadFromStream(Stream: TStream; out Root: TSyntaxNode;
      out ModifiedAt: TDateTime; out SourcePath: string): Boolean;
    class function SaveToFile(const FileName: string; Root: TSyntaxNode;
      ModifiedAt: TDateTime; const SourcePath: string): Boolean;
    class function LoadFromFile(const FileName: string; out Root: TSyntaxNode;
      out ModifiedAt: TDateTime; out SourcePath: string): Boolean;
  end;

implementation

const
  CSignature: AnsiString = 'DAST_MCP_V01'#26;
  CVersion: Cardinal = $03000000;

{ TFullASTSerializer }

function TFullASTSerializer.CheckSignature: Boolean;
var
  Sig: AnsiString;
begin
  SetLength(Sig, Length(CSignature));
  Result := (FStream.Read(Sig[1], Length(CSignature)) = Length(CSignature))
        and (Sig = CSignature);
end;

function TFullASTSerializer.CheckVersion: Boolean;
var
  Ver: Cardinal;
begin
  Result := (FStream.Read(Ver, 4) = 4) and (Ver = CVersion);
end;

function TFullASTSerializer.CreateNode(AClass: TNodeClass;
  AType: TSyntaxNodeType): TSyntaxNode;
begin
  case AClass of
    ncSyntax:   Result := TSyntaxNode.Create(AType);
    ncCompound: Result := TCompoundSyntaxNode.Create(AType);
    ncValued:   Result := TValuedSyntaxNode.Create(AType);
    ncComment:  Result := TCommentNode.Create(AType);
  else
    raise Exception.Create('TFullASTSerializer.CreateNode: Unexpected node class');
  end;
end;

function TFullASTSerializer.ReadNumber(var Num: Cardinal): Boolean;
var
  LowPart: Byte;
  Shift: Integer;
begin
  Result := False;
  Shift := 0;
  Num := 0;
  repeat
    if FStream.Read(LowPart, 1) <> 1 then
      Exit;
    Num := Num or ((LowPart and $7F) shl Shift);
    Inc(Shift, 7);
  until (LowPart and $80) = 0;
  Result := True;
end;

function TFullASTSerializer.ReadString(var Str: string): Boolean;
var
  Id: Integer;
  Len: Cardinal;
  U8: UTF8String;
begin
  Result := False;
  if not ReadNumber(Len) then
    Exit;
  if (Len shr 24) = $FF then
  begin
    Id := Len and $00FFFFFF;
    if Id >= FStringList.Count then
      Exit;
    Str := FStringList[Id];
  end
  else
  begin
    SetLength(U8, Len);
    if Len > 0 then
      if Cardinal(FStream.Read(U8[1], Len)) <> Len then
        Exit;
    Str := UTF8ToUnicodeString(U8);
    if Length(Str) > 4 then
      FStringList.Add(Str);
  end;
  Result := True;
end;

function TFullASTSerializer.ReadNode(var Node: TSyntaxNode): Boolean;
var
  ChildNode: TSyntaxNode;
  I: Integer;
  NC: TNodeClass;
  Num, NumSub: Cardinal;
  Str: string;
begin
  Result := False;
  Node := nil;

  if (not ReadNumber(Num)) or (Num > Cardinal(Ord(High(TNodeClass)))) then
    Exit;
  NC := TNodeClass(Num);

  if (not ReadNumber(Num)) or (Num > Ord(High(TSyntaxNodeType))) then
    Exit;
  Node := CreateNode(NC, TSyntaxNodeType(Num));
  try
    // Col
    if (not ReadNumber(Num)) or (Num > Cardinal(High(Integer))) then Exit;
    Node.Col := Num;
    // Line
    if (not ReadNumber(Num)) or (Num > Cardinal(High(Integer))) then Exit;
    Node.Line := Num;
    // LineSeq
    if (not ReadNumber(Num)) or (Num > Cardinal(High(Integer))) then Exit;
    Node.LineSeq := Num;
    // FileName
    if not ReadString(Str) then Exit;
    Node.FileName := Str;

    case NC of
      ncCompound:
        begin
          if (not ReadNumber(Num)) or (Num > Cardinal(High(Integer))) then Exit;
          TCompoundSyntaxNode(Node).EndCol := Num;
          if (not ReadNumber(Num)) or (Num > Cardinal(High(Integer))) then Exit;
          TCompoundSyntaxNode(Node).EndLine := Num;
        end;
      ncValued:
        begin
          if not ReadString(Str) then Exit;
          TValuedSyntaxNode(Node).Value := Str;
        end;
      ncComment:
        begin
          if not ReadString(Str) then Exit;
          TCommentNode(Node).Text := Str;
        end;
    end;

    // Attributes
    if not ReadNumber(NumSub) then Exit;
    for I := 1 to NumSub do
    begin
      if (not ReadNumber(Num)) or (Num > Cardinal(Ord(High(TAttributeName)))) then Exit;
      if not ReadString(Str) then Exit;
      Node.SetAttribute(TAttributeName(Num), Str);
    end;

    // Children
    if not ReadNumber(NumSub) then Exit;
    for I := 1 to NumSub do
    begin
      if not ReadNode(ChildNode) then Exit;
      Node.AddChild(ChildNode);
    end;

    Result := True;
  finally
    if not Result then
    begin
      Node.Free;
      Node := nil;
    end;
  end;
end;

function TFullASTSerializer.WriteNumber(Num: Cardinal): Boolean;
var
  LowPart: Byte;
begin
  Result := False;
  repeat
    LowPart := Num and $7F;
    Num := Num shr 7;
    if Num <> 0 then
      LowPart := LowPart or $80;
    if FStream.Write(LowPart, 1) <> 1 then
      Exit;
  until Num = 0;
  Result := True;
end;

function TFullASTSerializer.WriteString(const S: string): Boolean;
var
  Id, Len: Integer;
  U8: UTF8String;
begin
  Result := False;
  if (Length(S) > 4) and FStringTable.TryGetValue(S, Id) then
  begin
    if not WriteNumber(Cardinal(Id) or $FF000000) then
      Exit;
  end
  else
  begin
    if Length(S) > 4 then
    begin
      FStringTable.Add(S, FStringTable.Count);
      if FStringTable.Count > $FFFFFF then
        raise Exception.Create('TFullASTSerializer.WriteString: Too many strings!');
    end;
    U8 := UTF8Encode(S);
    Len := Length(U8);
    if not WriteNumber(Len) then
      Exit;
    if Len > 0 then
      if FStream.Write(U8[1], Len) <> Len then
        Exit;
  end;
  Result := True;
end;

function TFullASTSerializer.WriteNode(Node: TSyntaxNode): Boolean;
var
  Attr: TAttributeEntry;
  ChildNode: TSyntaxNode;
  NC: TNodeClass;
begin
  Result := False;

  if Node is TCompoundSyntaxNode then
    NC := ncCompound
  else if Node is TValuedSyntaxNode then
    NC := ncValued
  else if Node is TCommentNode then
    NC := ncComment
  else
    NC := ncSyntax;

  if not WriteNumber(Ord(NC)) then Exit;
  if not WriteNumber(Ord(Node.Typ)) then Exit;
  if not WriteNumber(Node.Col) then Exit;
  if not WriteNumber(Node.Line) then Exit;
  if not WriteNumber(Node.LineSeq) then Exit;
  if not WriteString(Node.FileName) then Exit;

  case NC of
    ncCompound:
      begin
        if not WriteNumber(TCompoundSyntaxNode(Node).EndCol) then Exit;
        if not WriteNumber(TCompoundSyntaxNode(Node).EndLine) then Exit;
      end;
    ncValued:
      if not WriteString(TValuedSyntaxNode(Node).Value) then Exit;
    ncComment:
      if not WriteString(TCommentNode(Node).Text) then Exit;
  end;

  if not WriteNumber(Length(Node.Attributes)) then Exit;
  for Attr in Node.Attributes do
  begin
    if not WriteNumber(Ord(Attr.Key)) then Exit;
    if not WriteString(Attr.Value) then Exit;
  end;

  if not WriteNumber(Length(Node.ChildNodes)) then Exit;
  for ChildNode in Node.ChildNodes do
    if not WriteNode(ChildNode) then Exit;

  Result := True;
end;

class function TFullASTSerializer.WriteToStream(Stream: TStream;
  Root: TSyntaxNode; ModifiedAt: TDateTime; const SourcePath: string): Boolean;
var
  Ser: TFullASTSerializer;
  Ver: Cardinal;
  ModDbl: Double;
  PathU8: UTF8String;
  PathLen: Cardinal;
begin
  Result := False;
  Ser := TFullASTSerializer.Create;
  try
    Ser.FStringTable := TDictionary<string, Integer>.Create;
    try
      Ser.FStream := Stream;

      // Signature
      if Stream.Write(CSignature[1], Length(CSignature)) <> Length(CSignature) then
        Exit;

      // Version
      Ver := CVersion;
      if Stream.Write(Ver, 4) <> 4 then
        Exit;

      // ModifiedAt
      ModDbl := ModifiedAt;
      if Stream.Write(ModDbl, SizeOf(Double)) <> SizeOf(Double) then
        Exit;

      // SourcePath (length-prefixed UTF-8)
      PathU8 := UTF8Encode(SourcePath);
      PathLen := Length(PathU8);
      if not Ser.WriteNumber(PathLen) then
        Exit;
      if PathLen > 0 then
        if Stream.Write(PathU8[1], PathLen) <> Integer(PathLen) then
          Exit;

      // Node tree
      if not Ser.WriteNode(Root) then
        Exit;

      Result := True;
    finally
      Ser.FStringTable.Free;
    end;
  finally
    Ser.Free;
  end;
end;

class function TFullASTSerializer.ReadFromStream(Stream: TStream;
  out Root: TSyntaxNode; out ModifiedAt: TDateTime;
  out SourcePath: string): Boolean;
var
  Ser: TFullASTSerializer;
  ModDbl: Double;
  PathLen: Cardinal;
  PathU8: UTF8String;
  Node: TSyntaxNode;
begin
  Result := False;
  Root := nil;
  ModifiedAt := 0;
  SourcePath := '';

  Ser := TFullASTSerializer.Create;
  try
    Ser.FStringList := TStringList.Create;
    try
      Ser.FStream := Stream;

      if not Ser.CheckSignature then Exit;
      if not Ser.CheckVersion then Exit;

      // ModifiedAt
      if Stream.Read(ModDbl, SizeOf(Double)) <> SizeOf(Double) then Exit;
      ModifiedAt := ModDbl;

      // SourcePath
      if not Ser.ReadNumber(PathLen) then Exit;
      if PathLen > 0 then
      begin
        SetLength(PathU8, PathLen);
        if Cardinal(Stream.Read(PathU8[1], PathLen)) <> PathLen then Exit;
        SourcePath := UTF8ToUnicodeString(PathU8);
      end;

      // Node tree
      if not Ser.ReadNode(Node) then Exit;
      Root := Node;

      Result := True;
    finally
      Ser.FStringList.Free;
    end;
  finally
    Ser.Free;
  end;
end;

class function TFullASTSerializer.SaveToFile(const FileName: string;
  Root: TSyntaxNode; ModifiedAt: TDateTime; const SourcePath: string): Boolean;
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  try
    Result := WriteToStream(FS, Root, ModifiedAt, SourcePath);
  finally
    FS.Free;
  end;
end;

class function TFullASTSerializer.LoadFromFile(const FileName: string;
  out Root: TSyntaxNode; out ModifiedAt: TDateTime;
  out SourcePath: string): Boolean;
var
    FS: TFileStream;
    MS: TMemoryStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    MS := TMemoryStream.Create;
    try
      MS.CopyFrom(FS, 0);   // slurp entire file at once
      MS.Position := 0;
      Result := ReadFromStream(MS, Root, ModifiedAt, SourcePath);
    finally
      MS.Free;
    end;
  finally
    FS.Free;
  end;
end;

end.
