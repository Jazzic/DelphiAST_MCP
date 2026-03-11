unit AST.Query;

interface

uses
  SysUtils, Classes, Generics.Collections,
  System.JSON,
  DelphiAST.Classes, DelphiAST.Consts;

  { Extract top-level structure: unit name, uses, types, constants, routines }
  function ExtractUnitOverview(Tree: TSyntaxNode): TJSONObject;

  { Detailed type info: fields, methods, properties, inheritance, visibility }
  function ExtractTypeDetail(Tree: TSyntaxNode; const TypeName: string): TJSONObject;

  { Method implementation body as simplified statement-level AST }
  function ExtractMethodBody(Tree: TSyntaxNode; const MethodName: string): TJSONObject;

  { Search for declarations matching a name pattern }
  function FindReferences(Tree: TSyntaxNode; const FileName, Pattern: string;
    const Kind: string): TJSONArray;

  { Unit dependency graph }
  function ExtractUsesGraph(Tree: TSyntaxNode; const UnitName: string): TJSONObject;

  { Raw AST subtree as compact JSON }
  function ExtractSyntaxTree(Tree: TSyntaxNode; const Path: string;
    MaxDepth: Integer): TJSONObject;

  { Render an expression node as Delphi source text }
  function ExprToSource(Node: TSyntaxNode): string;

  { Find all usage sites of an identifier across the AST }
  function FindUsages(Tree: TSyntaxNode; const FileName, IdentName: string): TJSONArray;

  type
    TCallInfo = record
      CalledName: string;    // Full expression: "FList.Add"
      SimpleName: string;    // Final identifier: "Add"
      Line: Integer;
    end;

    TSymbolLocation = record
      Found: Boolean;
      Name: string;
      StartLine: Integer;
      EndLine: Integer;
      Kind: string;
    end;

  { Locate a symbol (method or type) and return its line range }
  function LocateSymbol(Tree: TSyntaxNode; const SymbolName: string): TSymbolLocation;

  { Extract ancestor type names from a type declaration }
  function ExtractAncestorNames(Tree: TSyntaxNode; const TypeName: string): TArray<string>;

  { Extract all calls made from a method implementation }
  function ExtractCallsFromMethod(Tree: TSyntaxNode; const MethodName: string): TArray<TCallInfo>;

  { Find the AST node at a specific file position }
  function SymbolAtPosition(Tree: TSyntaxNode; Line, Col: Integer): TJSONObject;

implementation

uses
  StrUtils;

{ ----- helpers ----- }

function NodeValue(Node: TSyntaxNode): string;
begin
  if Node is TValuedSyntaxNode then
    Result := TValuedSyntaxNode(Node).Value
  else
    Result := '';
end;

function NodeName(Node: TSyntaxNode): string;
begin
  Result := Node.GetAttribute(anName);
  if (Result = '') and (Node is TValuedSyntaxNode) then
    Result := TValuedSyntaxNode(Node).Value;
end;

function NodeKind(Node: TSyntaxNode): string;
begin
  Result := Node.GetAttribute(anKind);
end;

function NodeTypeName(Node: TSyntaxNode): string;
begin
  Result := SyntaxNodeNames[Node.Typ];
end;

function FindChildNodes(Node: TSyntaxNode; Typ: TSyntaxNodeType): TArray<TSyntaxNode>;
var
  List: TList<TSyntaxNode>;
  Child: TSyntaxNode;
begin
  List := TList<TSyntaxNode>.Create;
  try
    for Child in Node.ChildNodes do
      if Child.Typ = Typ then
        List.Add(Child);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure CollectNodes(Node: TSyntaxNode; Typ: TSyntaxNodeType;
  List: TList<TSyntaxNode>);
var
  Child: TSyntaxNode;
begin
  if Node.Typ = Typ then
    List.Add(Node);
  for Child in Node.ChildNodes do
    CollectNodes(Child, Typ, List);
end;

function FindSection(Tree: TSyntaxNode; Typ: TSyntaxNodeType): TSyntaxNode;
var
  Child: TSyntaxNode;
begin
  Result := Tree.FindNode(Typ);
  if Result = nil then
    for Child in Tree.ChildNodes do
    begin
      Result := FindSection(Child, Typ);
      if Result <> nil then
        Exit;
    end;
end;

{ ----- ExprToSource ----- }

function ExprToSource(Node: TSyntaxNode): string;
var
  Child: TSyntaxNode;
  Parts: TStringList;
begin
  if Node = nil then
    Exit('');

  case Node.Typ of
    ntIdentifier:
      Result := NodeName(Node);
    ntLiteral:
      begin
        if Node is TValuedSyntaxNode then
          Result := TValuedSyntaxNode(Node).Value
        else
          Result := Node.GetAttribute(anName);
      end;
    ntDot:
      begin
        if Length(Node.ChildNodes) = 2 then
          Result := ExprToSource(Node.ChildNodes[0]) + '.' + ExprToSource(Node.ChildNodes[1])
        else
          Result := '.';
      end;
    ntCall:
      begin
        if Length(Node.ChildNodes) >= 1 then
        begin
          Result := ExprToSource(Node.ChildNodes[0]);
          if Length(Node.ChildNodes) >= 2 then
          begin
            Parts := TStringList.Create;
            try
              for Child in Node.ChildNodes[1].ChildNodes do
                Parts.Add(ExprToSource(Child));
              Result := Result + '(' + String.Join(', ', Parts.ToStringArray) + ')';
            finally
              Parts.Free;
            end;
          end;
        end;
      end;
    ntAdd: Result := ExprToSource(Node.ChildNodes[0]) + ' + ' + ExprToSource(Node.ChildNodes[1]);
    ntSub: Result := ExprToSource(Node.ChildNodes[0]) + ' - ' + ExprToSource(Node.ChildNodes[1]);
    ntMul: Result := ExprToSource(Node.ChildNodes[0]) + ' * ' + ExprToSource(Node.ChildNodes[1]);
    ntFDiv: Result := ExprToSource(Node.ChildNodes[0]) + ' / ' + ExprToSource(Node.ChildNodes[1]);
    ntDiv: Result := ExprToSource(Node.ChildNodes[0]) + ' div ' + ExprToSource(Node.ChildNodes[1]);
    ntMod: Result := ExprToSource(Node.ChildNodes[0]) + ' mod ' + ExprToSource(Node.ChildNodes[1]);
    ntEqual: Result := ExprToSource(Node.ChildNodes[0]) + ' = ' + ExprToSource(Node.ChildNodes[1]);
    ntNotEqual: Result := ExprToSource(Node.ChildNodes[0]) + ' <> ' + ExprToSource(Node.ChildNodes[1]);
    ntLower: Result := ExprToSource(Node.ChildNodes[0]) + ' < ' + ExprToSource(Node.ChildNodes[1]);
    ntGreater: Result := ExprToSource(Node.ChildNodes[0]) + ' > ' + ExprToSource(Node.ChildNodes[1]);
    ntLowerEqual: Result := ExprToSource(Node.ChildNodes[0]) + ' <= ' + ExprToSource(Node.ChildNodes[1]);
    ntGreaterEqual: Result := ExprToSource(Node.ChildNodes[0]) + ' >= ' + ExprToSource(Node.ChildNodes[1]);
    ntAnd: Result := ExprToSource(Node.ChildNodes[0]) + ' and ' + ExprToSource(Node.ChildNodes[1]);
    ntOr: Result := ExprToSource(Node.ChildNodes[0]) + ' or ' + ExprToSource(Node.ChildNodes[1]);
    ntNot: Result := 'not ' + ExprToSource(Node.ChildNodes[0]);
    ntUnaryMinus: Result := '-' + ExprToSource(Node.ChildNodes[0]);
    ntAddr: Result := '@' + ExprToSource(Node.ChildNodes[0]);
    ntDeref: Result := ExprToSource(Node.ChildNodes[0]) + '^';
    ntIndexed:
      begin
        if Length(Node.ChildNodes) >= 1 then
        begin
          Parts := TStringList.Create;
          try
            for Child in Node.ChildNodes do
              Parts.Add(ExprToSource(Child));
            Result := Parts[0] + '[' + String.Join(', ', Copy(Parts.ToStringArray, 1)) + ']';
          finally
            Parts.Free;
          end;
        end;
      end;
    ntAs: Result := ExprToSource(Node.ChildNodes[0]) + ' as ' + ExprToSource(Node.ChildNodes[1]);
    ntIs: Result := ExprToSource(Node.ChildNodes[0]) + ' is ' + ExprToSource(Node.ChildNodes[1]);
    ntIn: Result := ExprToSource(Node.ChildNodes[0]) + ' in ' + ExprToSource(Node.ChildNodes[1]);
    ntInherited:
      begin
        if Length(Node.ChildNodes) > 0 then
          Result := 'inherited ' + ExprToSource(Node.ChildNodes[0])
        else
          Result := 'inherited';
      end;
    ntExpression:
      begin
        if Length(Node.ChildNodes) > 0 then
          Result := ExprToSource(Node.ChildNodes[0])
        else
          Result := '';
      end;
    ntValue:
      begin
        if Node is TValuedSyntaxNode then
          Result := TValuedSyntaxNode(Node).Value
        else if Length(Node.ChildNodes) > 0 then
          Result := ExprToSource(Node.ChildNodes[0])
        else
          Result := NodeName(Node);
      end;
    ntGeneric:
      begin
        if Length(Node.ChildNodes) >= 2 then
        begin
          Result := ExprToSource(Node.ChildNodes[0]) + '<';
          Parts := TStringList.Create;
          try
            for Child in Node.ChildNodes[1].ChildNodes do
              Parts.Add(ExprToSource(Child));
            Result := Result + String.Join(', ', Parts.ToStringArray) + '>';
          finally
            Parts.Free;
          end;
        end;
      end;
    ntSet:
      begin
        Parts := TStringList.Create;
        try
          for Child in Node.ChildNodes do
            Parts.Add(ExprToSource(Child));
          Result := '[' + String.Join(', ', Parts.ToStringArray) + ']';
        finally
          Parts.Free;
        end;
      end;
  else
    // Fallback: try name attribute, then recurse children
    Result := NodeName(Node);
    if (Result = '') and Node.HasChildren then
    begin
      Parts := TStringList.Create;
      try
        for Child in Node.ChildNodes do
          Parts.Add(ExprToSource(Child));
        Result := String.Join(' ', Parts.ToStringArray);
      finally
        Parts.Free;
      end;
    end;
    if Result = '' then
      Result := NodeTypeName(Node);
  end;
end;

{ ----- extract uses list ----- }

function ExtractUsesList(UsesNode: TSyntaxNode): TJSONArray;
var
  Child: TSyntaxNode;
  Name: string;
begin
  Result := TJSONArray.Create;
  if UsesNode = nil then
    Exit;
  for Child in UsesNode.ChildNodes do
  begin
    Name := NodeName(Child);
    if Name <> '' then
      Result.Add(Name);
  end;
end;

{ ----- extract type name from type node ----- }

function GetTypeName(TypeNode: TSyntaxNode): string;
var
  NameNode: TSyntaxNode;
begin
  NameNode := TypeNode.FindNode(ntName);
  if NameNode <> nil then
    Result := NodeName(NameNode)
  else
    Result := NodeName(TypeNode);
end;

function GetTypeKindStr(TypeNode: TSyntaxNode): string;
var
  TypeChild: TSyntaxNode;
begin
  Result := NodeTypeName(TypeNode);
  TypeChild := TypeNode.FindNode(ntType);
  if TypeChild <> nil then
    Result := NodeName(TypeChild);
end;

{ ----- ExtractUnitOverview ----- }

function ExtractUnitOverview(Tree: TSyntaxNode): TJSONObject;
var
  IntfNode, ImplNode, TypeChild: TSyntaxNode;
  UsesIntf, UsesImpl: TJSONArray;
  Types, Constants, Routines: TJSONArray;
  Obj: TJSONObject;
  UnitName, Name, Kind: string;
  TypeDecls: TList<TSyntaxNode>;
  MethodNodes: TList<TSyntaxNode>;
  ConstNodes: TList<TSyntaxNode>;
  N: TSyntaxNode;
begin
  Result := TJSONObject.Create;

  // Unit name
  UnitName := NodeName(Tree);
  if UnitName <> '' then
    Result.AddPair('name', UnitName);

  // Interface section
  IntfNode := Tree.FindNode(ntInterface);
  ImplNode := Tree.FindNode(ntImplementation);

  // Uses clauses
  if IntfNode <> nil then
  begin
    UsesIntf := ExtractUsesList(IntfNode.FindNode(ntUses));
    if UsesIntf.Count > 0 then
      Result.AddPair('uses_interface', UsesIntf)
    else
      UsesIntf.Free;
  end;

  if ImplNode <> nil then
  begin
    UsesImpl := ExtractUsesList(ImplNode.FindNode(ntUses));
    if UsesImpl.Count > 0 then
      Result.AddPair('uses_implementation', UsesImpl)
    else
      UsesImpl.Free;
  end;

  // Type declarations
  Types := TJSONArray.Create;
  TypeDecls := TList<TSyntaxNode>.Create;
  try
    if IntfNode <> nil then
      CollectNodes(IntfNode, ntTypeDecl, TypeDecls);
    if ImplNode <> nil then
      CollectNodes(ImplNode, ntTypeDecl, TypeDecls);

    for N in TypeDecls do
    begin
      Name := NodeName(N);
      if Name = '' then Continue;

      Obj := TJSONObject.Create;
      Obj.AddPair('name', Name);
      Obj.AddPair('line', TJSONNumber.Create(N.Line));

      TypeChild := N.FindNode(ntType);
      if TypeChild <> nil then
      begin
        Kind := NodeName(TypeChild);
        if Kind <> '' then
          Obj.AddPair('kind', Kind);
      end;

      Types.Add(Obj);
    end;
  finally
    TypeDecls.Free;
  end;
  if Types.Count > 0 then
    Result.AddPair('types', Types)
  else
    Types.Free;

  // Constants
  Constants := TJSONArray.Create;
  ConstNodes := TList<TSyntaxNode>.Create;
  try
    if IntfNode <> nil then
      CollectNodes(IntfNode, ntConstant, ConstNodes);
    if ImplNode <> nil then
      CollectNodes(ImplNode, ntConstant, ConstNodes);

    for N in ConstNodes do
    begin
      Name := NodeName(N);
      if Name = '' then Continue;
      Obj := TJSONObject.Create;
      Obj.AddPair('name', Name);
      Obj.AddPair('line', TJSONNumber.Create(N.Line));
      Constants.Add(Obj);
    end;
  finally
    ConstNodes.Free;
  end;
  if Constants.Count > 0 then
    Result.AddPair('constants', Constants)
  else
    Constants.Free;

  // Routines (top-level methods in interface and implementation)
  Routines := TJSONArray.Create;
  MethodNodes := TList<TSyntaxNode>.Create;
  try
    if IntfNode <> nil then
      CollectNodes(IntfNode, ntMethod, MethodNodes);
    if ImplNode <> nil then
      CollectNodes(ImplNode, ntMethod, MethodNodes);

    for N in MethodNodes do
    begin
      Name := NodeName(N);
      if Name = '' then Continue;
      // Skip methods that are children of type declarations
      if (N.ParentNode <> nil) and
         (N.ParentNode.Typ in [ntPublic, ntPrivate, ntProtected, ntPublished,
           ntStrictPrivate, ntStrictProtected, ntType]) then
        Continue;

      Obj := TJSONObject.Create;
      Obj.AddPair('name', Name);
      Obj.AddPair('line', TJSONNumber.Create(N.Line));
      Kind := NodeKind(N);
      if Kind <> '' then
        Obj.AddPair('kind', Kind);
      Routines.Add(Obj);
    end;
  finally
    MethodNodes.Free;
  end;
  if Routines.Count > 0 then
    Result.AddPair('routines', Routines)
  else
    Routines.Free;
end;

{ ----- ExtractTypeDetail ----- }

function ExtractParamSignature(ParamsNode: TSyntaxNode): string;
var
  Param, TypeNode, NameNode: TSyntaxNode;
  Parts: TStringList;
  ParamStr, ParamName, ParamType, Modifier: string;
begin
  if ParamsNode = nil then
    Exit('');

  Parts := TStringList.Create;
  try
    for Param in ParamsNode.ChildNodes do
    begin
      if Param.Typ <> ntParameter then Continue;

      NameNode := Param.FindNode(ntName);
      TypeNode := Param.FindNode(ntType);

      if NameNode <> nil then
        ParamName := NodeName(NameNode)
      else
        ParamName := '';

      if TypeNode <> nil then
        ParamType := NodeName(TypeNode)
      else
        ParamType := '';

      Modifier := Param.GetAttribute(anKind);

      ParamStr := '';
      if Modifier <> '' then
        ParamStr := Modifier + ' ';
      ParamStr := ParamStr + ParamName;
      if ParamType <> '' then
        ParamStr := ParamStr + ': ' + ParamType;

      Parts.Add(ParamStr);
    end;
    Result := String.Join('; ', Parts.ToStringArray);
  finally
    Parts.Free;
  end;
end;

function ExtractMethodInfo(MethodNode: TSyntaxNode): TJSONObject;
var
  Name, Kind, Binding: string;
  ParamsNode, RetNode: TSyntaxNode;
  Sig, RetType: string;
begin
  Result := TJSONObject.Create;

  Name := NodeName(MethodNode);
  Result.AddPair('name', Name);
  Result.AddPair('line', TJSONNumber.Create(MethodNode.Line));

  Kind := NodeKind(MethodNode);
  if Kind <> '' then
    Result.AddPair('kind', Kind);

  ParamsNode := MethodNode.FindNode(ntParameters);
  Sig := ExtractParamSignature(ParamsNode);
  if Sig <> '' then
    Result.AddPair('params', Sig);

  RetNode := MethodNode.FindNode(ntReturnType);
  if RetNode <> nil then
  begin
    RetType := NodeName(RetNode);
    if RetType <> '' then
      Result.AddPair('returns', RetType);
  end;

  Binding := MethodNode.GetAttribute(anMethodBinding);
  if Binding <> '' then
    Result.AddPair('binding', Binding);

  if MethodNode.GetAttribute(anAbstract) = 'true' then
    Result.AddPair('abstract', TJSONBool.Create(True));
end;

function ExtractPropertyInfo(PropNode: TSyntaxNode): TJSONObject;
var
  Name, PropType: string;
  TypeNode, ReadNode, WriteNode: TSyntaxNode;
begin
  Result := TJSONObject.Create;

  Name := NodeName(PropNode);
  Result.AddPair('name', Name);
  Result.AddPair('line', TJSONNumber.Create(PropNode.Line));

  TypeNode := PropNode.FindNode(ntType);
  if TypeNode <> nil then
  begin
    PropType := NodeName(TypeNode);
    if PropType <> '' then
      Result.AddPair('type', PropType);
  end;

  ReadNode := PropNode.FindNode(ntRead);
  if ReadNode <> nil then
  begin
    Name := NodeName(ReadNode);
    if (Name = '') and ReadNode.HasChildren then
      Name := ExprToSource(ReadNode.ChildNodes[0]);
    if Name <> '' then
      Result.AddPair('read', Name);
  end;

  WriteNode := PropNode.FindNode(ntWrite);
  if WriteNode <> nil then
  begin
    Name := NodeName(WriteNode);
    if (Name = '') and WriteNode.HasChildren then
      Name := ExprToSource(WriteNode.ChildNodes[0]);
    if Name <> '' then
      Result.AddPair('write', Name);
  end;
end;

function ExtractFieldInfo(FieldNode: TSyntaxNode): TJSONObject;
var
  Name: string;
  TypeNode, NameNode: TSyntaxNode;
begin
  Result := TJSONObject.Create;

  Name := NodeName(FieldNode);
  if Name = '' then
  begin
    NameNode := FieldNode.FindNode(ntName);
    if NameNode <> nil then
      Name := NodeName(NameNode);
  end;
  Result.AddPair('name', Name);
  Result.AddPair('line', TJSONNumber.Create(FieldNode.Line));

  TypeNode := FieldNode.FindNode(ntType);
  if TypeNode <> nil then
    Result.AddPair('type', NodeName(TypeNode));
end;

procedure ExtractVisibilitySection(VisNode: TSyntaxNode; Sections: TJSONObject);
var
  Child: TSyntaxNode;
  VisName: string;
  Methods, Properties, Fields: TJSONArray;
  SectionObj: TJSONObject;
begin
  case VisNode.Typ of
    ntPublic:          VisName := 'public';
    ntPrivate:         VisName := 'private';
    ntProtected:       VisName := 'protected';
    ntPublished:       VisName := 'published';
    ntStrictPrivate:   VisName := 'strict private';
    ntStrictProtected: VisName := 'strict protected';
  else
    VisName := 'public';
  end;

  Methods := TJSONArray.Create;
  Properties := TJSONArray.Create;
  Fields := TJSONArray.Create;

  for Child in VisNode.ChildNodes do
  begin
    case Child.Typ of
      ntMethod:
        Methods.Add(ExtractMethodInfo(Child));
      ntProperty:
        Properties.Add(ExtractPropertyInfo(Child));
      ntField, ntVariable:
        Fields.Add(ExtractFieldInfo(Child));
    end;
  end;

  SectionObj := TJSONObject.Create;
  if Fields.Count > 0 then
    SectionObj.AddPair('fields', Fields)
  else
    Fields.Free;
  if Methods.Count > 0 then
    SectionObj.AddPair('methods', Methods)
  else
    Methods.Free;
  if Properties.Count > 0 then
    SectionObj.AddPair('properties', Properties)
  else
    Properties.Free;

  if SectionObj.Count > 0 then
    Sections.AddPair(VisName, SectionObj)
  else
    SectionObj.Free;
end;

function FindTypeDecl(Tree: TSyntaxNode; const TypeName: string): TSyntaxNode;
var
  TypeDecls: TList<TSyntaxNode>;
  N: TSyntaxNode;
begin
  Result := nil;
  TypeDecls := TList<TSyntaxNode>.Create;
  try
    CollectNodes(Tree, ntTypeDecl, TypeDecls);
    for N in TypeDecls do
      if SameText(NodeName(N), TypeName) then
        Exit(N);
  finally
    TypeDecls.Free;
  end;
end;

function ExtractTypeDetail(Tree: TSyntaxNode; const TypeName: string): TJSONObject;
var
  TypeDecl, TypeNode, Child, AncestorNode: TSyntaxNode;
  Sections: TJSONObject;
  Ancestors: TJSONArray;
  AncChild: TSyntaxNode;
  TypeKind: string;
begin
  TypeDecl := FindTypeDecl(Tree, TypeName);
  if TypeDecl = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Type not found: ' + TypeName);
    Exit;
  end;

  Result := TJSONObject.Create;
  Result.AddPair('name', NodeName(TypeDecl));
  Result.AddPair('line', TJSONNumber.Create(TypeDecl.Line));

  TypeNode := TypeDecl.FindNode(ntType);
  if TypeNode <> nil then
  begin
    TypeKind := NodeName(TypeNode);
    // If type kind is empty, infer from node structure
    // DelphiAST stores interface/class as empty name in ntType node
    if TypeKind = '' then
    begin
      // Check for GUID child → it's an interface (only if has children)
      if TypeNode.HasChildren then
      begin
        for Child in TypeNode.ChildNodes do
        begin
          if Child.Typ = ntGuid then
          begin
            TypeKind := 'interface';
            Break;
          end;
        end;
        // If no GUID, check for visibility sections → it's a class
        if TypeKind = '' then
        begin
          for Child in TypeNode.ChildNodes do
            if Child.Typ in [ntPublic, ntPrivate, ntProtected, ntPublished,
              ntStrictPrivate, ntStrictProtected] then
            begin
              TypeKind := 'class';
              Break;
            end;
        end;
      end;
      // Default to class if still empty
      if TypeKind = '' then
        TypeKind := 'class';
    end;
    if TypeKind <> '' then
      Result.AddPair('kind', TypeKind);

    // Ancestors/inheritance
    Ancestors := TJSONArray.Create;
    for AncChild in TypeNode.ChildNodes do
    begin
      if AncChild.Typ = ntType then
      begin
        AncestorNode := AncChild;
        if NodeName(AncestorNode) <> '' then
          Ancestors.Add(NodeName(AncestorNode));
      end;
    end;
    if Ancestors.Count > 0 then
      Result.AddPair('ancestors', Ancestors)
    else
      Ancestors.Free;

    // Visibility sections
    Sections := TJSONObject.Create;
    for Child in TypeNode.ChildNodes do
    begin
      if Child.Typ in [ntPublic, ntPrivate, ntProtected, ntPublished,
        ntStrictPrivate, ntStrictProtected] then
        ExtractVisibilitySection(Child, Sections);
    end;
    if Sections.Count > 0 then
      Result.AddPair('sections', Sections)
    else
      Sections.Free;

    // For records/enums without visibility sections, extract directly
    if (Sections = nil) or (Sections.Count = 0) then
    begin
      // Check for enum values
      if TypeKind = 'enum' then
      begin
        var EnumValues := TJSONArray.Create;
        for Child in TypeNode.ChildNodes do
          if (Child.Typ = ntElement) or (Child.Typ = ntIdentifier) then
          begin
            var EName := NodeName(Child);
            if EName <> '' then
              EnumValues.Add(EName);
          end;
        if EnumValues.Count > 0 then
          Result.AddPair('values', EnumValues)
        else
          EnumValues.Free;
      end;

      // Check for fields directly in type node
      var DirectFields := TJSONArray.Create;
      for Child in TypeNode.ChildNodes do
        if Child.Typ in [ntField, ntVariable] then
          DirectFields.Add(ExtractFieldInfo(Child));
      if DirectFields.Count > 0 then
        Result.AddPair('fields', DirectFields)
      else
        DirectFields.Free;
    end;
  end;
end;

{ ----- ExtractMethodBody ----- }

function StatementsToJSON(Node: TSyntaxNode): TJSONArray; forward;

function StatementToJSON(Node: TSyntaxNode): TJSONObject;
var
  Child: TSyntaxNode;
  LHS, RHS: TSyntaxNode;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', NodeTypeName(Node));
  Result.AddPair('line', TJSONNumber.Create(Node.Line));

  case Node.Typ of
    ntAssign:
      begin
        LHS := Node.FindNode(ntLHS);
        RHS := Node.FindNode(ntRHS);
        if LHS <> nil then
        begin
          if Length(LHS.ChildNodes) > 0 then
            Result.AddPair('target', ExprToSource(LHS.ChildNodes[0]));
        end;
        if RHS <> nil then
        begin
          if Length(RHS.ChildNodes) > 0 then
            Result.AddPair('value', ExprToSource(RHS.ChildNodes[0]));
        end;
      end;
    ntCall:
      begin
        if Length(Node.ChildNodes) > 0 then
          Result.AddPair('expr', ExprToSource(Node));
      end;
    ntIf:
      begin
        // Expression
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('condition', ExprToSource(Child));
        // Then
        Child := Node.FindNode(ntThen);
        if (Child <> nil) and Child.HasChildren then
        begin
          var ThenStmts := StatementsToJSON(Child);
          if ThenStmts.Count > 0 then
            Result.AddPair('then', ThenStmts)
          else
            ThenStmts.Free;
        end;
        // Else
        Child := Node.FindNode(ntElse);
        if (Child <> nil) and Child.HasChildren then
        begin
          var ElseStmts := StatementsToJSON(Child);
          if ElseStmts.Count > 0 then
            Result.AddPair('else', ElseStmts)
          else
            ElseStmts.Free;
        end;
      end;
    ntFor:
      begin
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('expr', ExprToSource(Child));
        Child := Node.FindNode(ntStatements);
        if Child <> nil then
        begin
          var ForBody := StatementsToJSON(Child);
          if ForBody.Count > 0 then
            Result.AddPair('body', ForBody)
          else
            ForBody.Free;
        end;
      end;
    ntWhile:
      begin
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('condition', ExprToSource(Child));
        Child := Node.FindNode(ntStatements);
        if Child <> nil then
        begin
          var WhileBody := StatementsToJSON(Child);
          if WhileBody.Count > 0 then
            Result.AddPair('body', WhileBody)
          else
            WhileBody.Free;
        end;
      end;
    ntRepeat:
      begin
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('until', ExprToSource(Child));
        Child := Node.FindNode(ntStatements);
        if Child <> nil then
        begin
          var RepBody := StatementsToJSON(Child);
          if RepBody.Count > 0 then
            Result.AddPair('body', RepBody)
          else
            RepBody.Free;
        end;
      end;
    ntTry:
      begin
        Child := Node.FindNode(ntStatements);
        if Child <> nil then
        begin
          var TryBody := StatementsToJSON(Child);
          if TryBody.Count > 0 then
            Result.AddPair('body', TryBody)
          else
            TryBody.Free;
        end;
        Child := Node.FindNode(ntFinally);
        if (Child <> nil) then
        begin
          var FinBody := StatementsToJSON(Child);
          if FinBody.Count > 0 then
            Result.AddPair('finally', FinBody)
          else
            FinBody.Free;
        end;
        Child := Node.FindNode(ntExcept);
        if (Child <> nil) then
        begin
          var ExcBody := StatementsToJSON(Child);
          if ExcBody.Count > 0 then
            Result.AddPair('except', ExcBody)
          else
            ExcBody.Free;
        end;
      end;
    ntCase:
      begin
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('expr', ExprToSource(Child));
      end;
    ntRaise:
      begin
        if Length(Node.ChildNodes) > 0 then
          Result.AddPair('expr', ExprToSource(Node.ChildNodes[0]));
      end;
    ntWith:
      begin
        Child := Node.FindNode(ntExpression);
        if Child <> nil then
          Result.AddPair('expr', ExprToSource(Child));
        Child := Node.FindNode(ntStatements);
        if Child <> nil then
        begin
          var WithBody := StatementsToJSON(Child);
          if WithBody.Count > 0 then
            Result.AddPair('body', WithBody)
          else
            WithBody.Free;
        end;
      end;
    ntVariable:
      begin
        Result.AddPair('name', NodeName(Node));
        Child := Node.FindNode(ntType);
        if Child <> nil then
          Result.AddPair('vartype', NodeName(Child));
      end;
  else
    // For expression-level statements
    if Length(Node.ChildNodes) > 0 then
    begin
      var ExprStr := ExprToSource(Node);
      if ExprStr <> '' then
        Result.AddPair('expr', ExprStr);
    end;
  end;
end;

function StatementsToJSON(Node: TSyntaxNode): TJSONArray;
var
  Child: TSyntaxNode;
begin
  Result := TJSONArray.Create;
  for Child in Node.ChildNodes do
  begin
    if Child.Typ = ntStatements then
    begin
      // Recurse into nested statements blocks
      var Inner := StatementsToJSON(Child);
      var I: Integer;
      for I := 0 to Inner.Count - 1 do
        Result.AddElement(TJSONValue(Inner.Items[I].Clone));
      Inner.Free;
    end
    else if Child.Typ <> ntEmptyStatement then
      Result.Add(StatementToJSON(Child));
  end;
end;

function FindMethodImpl(Tree: TSyntaxNode; const MethodName: string): TSyntaxNode;
var
  ImplNode: TSyntaxNode;
  Methods: TList<TSyntaxNode>;
  M: TSyntaxNode;
  Name: string;
begin
  Result := nil;
  ImplNode := Tree.FindNode(ntImplementation);
  if ImplNode = nil then
    ImplNode := Tree;

  Methods := TList<TSyntaxNode>.Create;
  try
    CollectNodes(ImplNode, ntMethod, Methods);
    for M in Methods do
    begin
      Name := NodeName(M);
      if SameText(Name, MethodName) then
        Exit(M);
      // Also try ClassName.MethodName matching
      if Pos('.', MethodName) = 0 then
      begin
        // Match just the method part of Class.Method
        if Pos('.', Name) > 0 then
        begin
          if SameText(Copy(Name, Pos('.', Name) + 1), MethodName) then
            Exit(M);
        end;
      end;
    end;
  finally
    Methods.Free;
  end;
end;

function ExtractMethodBody(Tree: TSyntaxNode; const MethodName: string): TJSONObject;
var
  MethodNode, StmtsNode, VarsNode, Child: TSyntaxNode;
  Stmts: TJSONArray;
  Locals: TJSONArray;
begin
  MethodNode := FindMethodImpl(Tree, MethodName);
  if MethodNode = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Method not found: ' + MethodName);
    Exit;
  end;

  Result := TJSONObject.Create;
  Result.AddPair('name', NodeName(MethodNode));
  Result.AddPair('line', TJSONNumber.Create(MethodNode.Line));

  // Local variables
  Locals := TJSONArray.Create;
  VarsNode := MethodNode.FindNode(ntVariables);
  if VarsNode <> nil then
  begin
    for Child in VarsNode.ChildNodes do
      if Child.Typ = ntVariable then
      begin
        var VarObj := TJSONObject.Create;
        var VarName := NodeName(Child);
        if VarName = '' then
        begin
          var VarNameNode := Child.FindNode(ntName);
          if VarNameNode <> nil then
            VarName := NodeName(VarNameNode);
        end;
        VarObj.AddPair('name', VarName);
        var VarType := Child.FindNode(ntType);
        if VarType <> nil then
          VarObj.AddPair('type', NodeName(VarType));
        Locals.Add(VarObj);
      end;
  end;
  if Locals.Count > 0 then
    Result.AddPair('locals', Locals)
  else
    Locals.Free;

  // Statements
  StmtsNode := MethodNode.FindNode(ntStatements);
  if StmtsNode <> nil then
  begin
    Stmts := StatementsToJSON(StmtsNode);
    if Stmts.Count > 0 then
      Result.AddPair('statements', Stmts)
    else
      Stmts.Free;
  end;
end;

{ ----- FindReferences ----- }

function FindReferences(Tree: TSyntaxNode; const FileName, Pattern: string;
  const Kind: string): TJSONArray;
var
  AllDecls: TList<TSyntaxNode>;
  N: TSyntaxNode;
  Name, DeclKind: string;
  LowerPattern: string;
  Obj: TJSONObject;

  procedure CollectDeclarations(Node: TSyntaxNode);
  var
    Child: TSyntaxNode;
  begin
    case Node.Typ of
      ntTypeDecl:
        begin
          Name := NodeName(Node);
          if Name <> '' then
            AllDecls.Add(Node);
        end;
      ntMethod:
        begin
          Name := NodeName(Node);
          if Name <> '' then
            AllDecls.Add(Node);
        end;
      ntVariable, ntConstant:
        begin
          Name := NodeName(Node);
          if Name <> '' then
            AllDecls.Add(Node);
        end;
    end;

    for Child in Node.ChildNodes do
      CollectDeclarations(Child);
  end;

  function MatchesKind(Node: TSyntaxNode; const FilterKind: string): Boolean;
  begin
    if FilterKind = '' then
      Exit(True);
    case Node.Typ of
      ntTypeDecl: Result := SameText(FilterKind, 'type');
      ntMethod:   Result := SameText(FilterKind, 'method');
      ntVariable: Result := SameText(FilterKind, 'variable');
      ntConstant: Result := SameText(FilterKind, 'constant');
    else
      Result := False;
    end;
  end;

begin
  Result := TJSONArray.Create;
  LowerPattern := LowerCase(Pattern);

  AllDecls := TList<TSyntaxNode>.Create;
  try
    CollectDeclarations(Tree);

    for N in AllDecls do
    begin
      Name := NodeName(N);
      if (LowerPattern <> '') and (Pos(LowerPattern, LowerCase(Name)) = 0) then
        Continue;
      if not MatchesKind(N, Kind) then
        Continue;

      Obj := TJSONObject.Create;
      Obj.AddPair('name', Name);
      Obj.AddPair('line', TJSONNumber.Create(N.Line));
      Obj.AddPair('file', FileName);

      case N.Typ of
        ntTypeDecl: DeclKind := 'type';
        ntMethod:   DeclKind := 'method';
        ntVariable: DeclKind := 'variable';
        ntConstant: DeclKind := 'constant';
      else
        DeclKind := NodeTypeName(N);
      end;
      Obj.AddPair('kind', DeclKind);

      Result.Add(Obj);
    end;
  finally
    AllDecls.Free;
  end;
end;

{ ----- ExtractUsesGraph ----- }

function ExtractUsesGraph(Tree: TSyntaxNode; const UnitName: string): TJSONObject;
var
  IntfNode, ImplNode: TSyntaxNode;
  IntfUses, ImplUses: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('unit', UnitName);

  IntfNode := Tree.FindNode(ntInterface);
  ImplNode := Tree.FindNode(ntImplementation);

  if IntfNode <> nil then
  begin
    IntfUses := ExtractUsesList(IntfNode.FindNode(ntUses));
    if IntfUses.Count > 0 then
      Result.AddPair('uses_interface', IntfUses)
    else
      IntfUses.Free;
  end;

  if ImplNode <> nil then
  begin
    ImplUses := ExtractUsesList(ImplNode.FindNode(ntUses));
    if ImplUses.Count > 0 then
      Result.AddPair('uses_implementation', ImplUses)
    else
      ImplUses.Free;
  end;
end;

{ ----- ExtractSyntaxTree ----- }

function NodeToCompactJSON(Node: TSyntaxNode; Depth, MaxDepth: Integer): TJSONObject;
var
  Child: TSyntaxNode;
  Children: TJSONArray;
  Attrs: TJSONObject;
  Attr: TAttributeEntry;
begin
  Result := TJSONObject.Create;
  Result.AddPair('t', NodeTypeName(Node));
  Result.AddPair('l', TJSONNumber.Create(Node.Line));

  if Node.HasAttributes then
  begin
    Attrs := TJSONObject.Create;
    for Attr in Node.Attributes do
      Attrs.AddPair(AttributeNameStrings[Attr.Key], Attr.Value);
    Result.AddPair('a', Attrs);
  end;

  if Node is TValuedSyntaxNode then
  begin
    var Val := TValuedSyntaxNode(Node).Value;
    if Val <> '' then
      Result.AddPair('v', Val);
  end;

  if Node.HasChildren and ((MaxDepth <= 0) or (Depth < MaxDepth)) then
  begin
    Children := TJSONArray.Create;
    for Child in Node.ChildNodes do
      Children.Add(NodeToCompactJSON(Child, Depth + 1, MaxDepth));
    Result.AddPair('c', Children);
  end
  else if Node.HasChildren then
    Result.AddPair('children_count', TJSONNumber.Create(Length(Node.ChildNodes)));
end;

function NavigateToPath(Node: TSyntaxNode; const Path: string): TSyntaxNode;
var
  Parts: TArray<string>;
  Part: string;
  Current: TSyntaxNode;
  Child: TSyntaxNode;
  Found: Boolean;
  Idx: Integer;
begin
  if Path = '' then
    Exit(Node);

  Current := Node;
  Parts := Path.Split(['/']);

  for Part in Parts do
  begin
    if Part = '' then Continue;
    Found := False;

    // Try as index first
    if TryStrToInt(Part, Idx) then
    begin
      if (Idx >= 0) and (Idx < Length(Current.ChildNodes)) then
      begin
        Current := Current.ChildNodes[Idx];
        Found := True;
      end;
    end;

    // Try as node type name
    if not Found then
    begin
      for Child in Current.ChildNodes do
      begin
        if SameText(NodeTypeName(Child), Part) or SameText(NodeName(Child), Part) then
        begin
          Current := Child;
          Found := True;
          Break;
        end;
      end;
    end;

    if not Found then
      Exit(nil);
  end;

  Result := Current;
end;

function ExtractSyntaxTree(Tree: TSyntaxNode; const Path: string;
  MaxDepth: Integer): TJSONObject;
var
  Target: TSyntaxNode;
begin
  Target := NavigateToPath(Tree, Path);
  if Target = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Path not found: ' + Path);
    Exit;
  end;

  Result := NodeToCompactJSON(Target, 0, MaxDepth);
end;

{ ----- FindUsages ----- }

function ClassifyUsageContext(Node: TSyntaxNode): string;
var
  P: TSyntaxNode;
begin
  P := Node.ParentNode;
  if P = nil then
    Exit('reference');

  case P.Typ of
    ntCall:
      Exit('call');
    ntAssign:
      begin
        // Check if this identifier is on LHS or RHS
        var LHS := P.FindNode(ntLHS);
        if LHS <> nil then
        begin
          // Walk up from Node to see if we're under LHS
          var Cur := Node;
          while (Cur <> nil) and (Cur <> P) do
          begin
            if Cur = LHS then
              Exit('write');
            Cur := Cur.ParentNode;
          end;
        end;
        Exit('read');
      end;
    ntLHS:
      Exit('write');
    ntRHS:
      Exit('read');
    ntDot:
      Exit('member_access');
    ntTypeDecl, ntType:
      Exit('type_ref');
    ntMethod:
      begin
        // If this is the method name node itself, it's a declaration
        if SameText(NodeName(Node), NodeName(P)) then
          Exit('declaration');
        Exit('reference');
      end;
    ntVariable, ntField, ntConstant, ntParameter:
      begin
        // Name child of a declaration is a declaration
        var NameNode := P.FindNode(ntName);
        if (NameNode <> nil) and (NameNode = Node) then
          Exit('declaration');
        if Node.Typ = ntName then
          Exit('declaration');
        Exit('reference');
      end;
    ntName:
      begin
        // ntName parent is typically a declaration context
        if P.ParentNode <> nil then
          case P.ParentNode.Typ of
            ntTypeDecl, ntMethod, ntVariable, ntField, ntConstant, ntParameter, ntProperty:
              Exit('declaration');
          end;
        Exit('reference');
      end;
  else
    Exit('reference');
  end;
end;

function FindUsages(Tree: TSyntaxNode; const FileName, IdentName: string): TJSONArray;
var
  LowerIdent: string;

  procedure WalkNode(Node: TSyntaxNode);
  var
    Child: TSyntaxNode;
    Name, Context, Qualified: string;
    Obj: TJSONObject;
  begin
    // Check if this node is an identifier matching the search name
    if Node.Typ = ntIdentifier then
    begin
      Name := NodeName(Node);
      if SameText(Name, IdentName) then
      begin
        Context := ClassifyUsageContext(Node);

        Obj := TJSONObject.Create;
        Obj.AddPair('name', Name);
        Obj.AddPair('line', TJSONNumber.Create(Node.Line));
        Obj.AddPair('col', TJSONNumber.Create(Node.Col));
        Obj.AddPair('context', Context);
        Obj.AddPair('file', FileName);

        // If inside a dot expression, include qualified name
        if (Node.ParentNode <> nil) and (Node.ParentNode.Typ = ntDot) then
        begin
          Qualified := ExprToSource(Node.ParentNode);
          if Qualified <> '' then
            Obj.AddPair('qualified', Qualified);
        end;

        Result.Add(Obj);
      end;
    end
    else if Node.Typ = ntName then
    begin
      // ntName nodes with matching value are also usages (declarations)
      Name := NodeName(Node);
      if SameText(Name, IdentName) then
      begin
        Context := ClassifyUsageContext(Node);

        Obj := TJSONObject.Create;
        Obj.AddPair('name', Name);
        Obj.AddPair('line', TJSONNumber.Create(Node.Line));
        Obj.AddPair('col', TJSONNumber.Create(Node.Col));
        Obj.AddPair('context', Context);
        Obj.AddPair('file', FileName);
        Result.Add(Obj);
      end;
    end;

    for Child in Node.ChildNodes do
      WalkNode(Child);
  end;

begin
  Result := TJSONArray.Create;
  LowerIdent := LowerCase(IdentName);
  WalkNode(Tree);
end;

{ ----- LocateSymbol ----- }

function GetNodeEndLine(Node: TSyntaxNode): Integer;
begin
  if Node is TCompoundSyntaxNode then
  begin
    Result := TCompoundSyntaxNode(Node).EndLine;
    if Result > 0 then
      Exit;
  end;
  Result := Node.Line;
end;

function LocateSymbol(Tree: TSyntaxNode; const SymbolName: string): TSymbolLocation;
var
  Methods, TypeDecls: TList<TSyntaxNode>;
  N: TSyntaxNode;
  Name: string;
begin
  Result.Found := False;
  Result.Name := '';
  Result.StartLine := 0;
  Result.EndLine := 0;
  Result.Kind := '';

  // Search methods first (most common request)
  Methods := TList<TSyntaxNode>.Create;
  try
    CollectNodes(Tree, ntMethod, Methods);
    for N in Methods do
    begin
      Name := NodeName(N);
      if SameText(Name, SymbolName) then
      begin
        Result.Found := True;
        Result.Name := Name;
        Result.StartLine := N.Line;
        Result.EndLine := GetNodeEndLine(N);
        Result.Kind := 'method';
        Exit;
      end;
      // Try matching just the method part of Class.Method
      if (Pos('.', SymbolName) = 0) and (Pos('.', Name) > 0) then
        if SameText(Copy(Name, Pos('.', Name) + 1), SymbolName) then
        begin
          Result.Found := True;
          Result.Name := Name;
          Result.StartLine := N.Line;
          Result.EndLine := GetNodeEndLine(N);
          Result.Kind := 'method';
          Exit;
        end;
    end;
  finally
    Methods.Free;
  end;

  // Search type declarations
  TypeDecls := TList<TSyntaxNode>.Create;
  try
    CollectNodes(Tree, ntTypeDecl, TypeDecls);
    for N in TypeDecls do
    begin
      Name := NodeName(N);
      if SameText(Name, SymbolName) then
      begin
        Result.Found := True;
        Result.Name := Name;
        Result.StartLine := N.Line;
        Result.EndLine := GetNodeEndLine(N);
        Result.Kind := 'type';
        Exit;
      end;
    end;
  finally
    TypeDecls.Free;
  end;
end;

{ ----- SymbolAtPosition ----- }

function SymbolAtPosition(Tree: TSyntaxNode; Line, Col: Integer): TJSONObject;
var
  Best: TSyntaxNode;
  BestDepth: Integer;

  function NodeContainsPos(Node: TSyntaxNode; L, C: Integer): Boolean;
  var
    EndL, EndC: Integer;
  begin
    if Node.Line = 0 then
      Exit(False);

    // Must be at or after the node start line
    if L < Node.Line then Exit(False);

    // Check start column on the start line
    if (L = Node.Line) and (Node.Col > 0) and (C < Node.Col) then
      Exit(False);

    // Determine end position
    EndL := 0;
    EndC := 0;
    if Node is TCompoundSyntaxNode then
    begin
      EndL := TCompoundSyntaxNode(Node).EndLine;
      EndC := TCompoundSyntaxNode(Node).EndCol;
    end;
    if EndL <= 0 then
    begin
      EndL := 0;
      EndC := 0;
    end;

    // If we have a valid end line, check against it
    if EndL > 0 then
    begin
      if L > EndL then Exit(False);
      if (L = EndL) and (EndC > 0) and (C > EndC) then
        Exit(False);
    end
    else if not Node.HasChildren then
    begin
      // Leaf node with no end info: only match its start line
      if L > Node.Line then Exit(False);
    end;
    // Else: node has children but no end line — treat as open-ended

    Result := True;
  end;

  procedure WalkForPosition(Node: TSyntaxNode; Depth: Integer);
  var
    Child: TSyntaxNode;
  begin
    if not NodeContainsPos(Node, Line, Col) then
      Exit;

    // This node contains the position - is it deeper than our current best?
    if Depth > BestDepth then
    begin
      Best := Node;
      BestDepth := Depth;
    end;

    for Child in Node.ChildNodes do
      WalkForPosition(Child, Depth + 1);
  end;

  function FindEnclosingOfType(Node: TSyntaxNode; Typ: TSyntaxNodeType): string;
  var
    P: TSyntaxNode;
  begin
    Result := '';
    P := Node.ParentNode;
    while P <> nil do
    begin
      if P.Typ = Typ then
      begin
        Result := NodeName(P);
        Exit;
      end;
      P := P.ParentNode;
    end;
  end;

begin
  Result := TJSONObject.Create;
  Best := nil;
  BestDepth := -1;

  WalkForPosition(Tree, 0);

  if Best = nil then
  begin
    Result.AddPair('error', 'No node found at position');
    Exit;
  end;

  Result.AddPair('type', NodeTypeName(Best));

  var Name := NodeName(Best);
  if Name <> '' then
    Result.AddPair('name', Name);

  Result.AddPair('line', TJSONNumber.Create(Best.Line));
  Result.AddPair('col', TJSONNumber.Create(Best.Col));

  // If inside a dot expression, include qualified name
  if (Best.ParentNode <> nil) and (Best.ParentNode.Typ = ntDot) then
  begin
    var Qualified := ExprToSource(Best.ParentNode);
    if Qualified <> '' then
      Result.AddPair('qualified', Qualified);
  end;

  // Enclosing method
  var EncMethod := FindEnclosingOfType(Best, ntMethod);
  if EncMethod <> '' then
    Result.AddPair('enclosing_method', EncMethod);

  // Enclosing type
  var EncType := FindEnclosingOfType(Best, ntTypeDecl);
  if EncType <> '' then
    Result.AddPair('enclosing_type', EncType);
end;

{ ----- ExtractAncestorNames ----- }

function ExtractAncestorNames(Tree: TSyntaxNode; const TypeName: string): TArray<string>;
var
  TypeDecl, TypeNode, AncChild: TSyntaxNode;
  List: TList<string>;
  Name: string;
begin
  TypeDecl := FindTypeDecl(Tree, TypeName);
  if TypeDecl = nil then
    Exit(nil);

  TypeNode := TypeDecl.FindNode(ntType);
  if TypeNode = nil then
    Exit(nil);

  List := TList<string>.Create;
  try
    for AncChild in TypeNode.ChildNodes do
    begin
      if AncChild.Typ = ntType then
      begin
        Name := NodeName(AncChild);
        if Name <> '' then
          List.Add(Name);
      end;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

{ ----- ExtractCallsFromMethod ----- }

function ExtractCallsFromMethod(Tree: TSyntaxNode; const MethodName: string): TArray<TCallInfo>;
var
  MethodNode, StmtsNode: TSyntaxNode;
  CallNodes, DotNodes: TList<TSyntaxNode>;
  N: TSyntaxNode;
  Info: TCallInfo;
  Results: TList<TCallInfo>;
  CalledExpr, SimpleName: string;
  DotPos: Integer;
begin
  MethodNode := FindMethodImpl(Tree, MethodName);
  if MethodNode = nil then
    Exit(nil);

  StmtsNode := MethodNode.FindNode(ntStatements);
  if StmtsNode = nil then
    Exit(nil);

  DotNodes := TList<TSyntaxNode>.Create;
  CallNodes := TList<TSyntaxNode>.Create;
  Results := TList<TCallInfo>.Create;
  try
    // First pass: explicit calls with parentheses (ntCall nodes)
    CollectNodes(StmtsNode, ntCall, CallNodes);
    for N in CallNodes do
    begin
      if Length(N.ChildNodes) < 1 then
        Continue;

      CalledExpr := ExprToSource(N.ChildNodes[0]);
      if CalledExpr = '' then
        Continue;

      // Extract simple name (portion after last dot)
      DotPos := LastDelimiter('.', CalledExpr);
      if DotPos > 0 then
        SimpleName := Copy(CalledExpr, DotPos + 1)
      else
        SimpleName := CalledExpr;

      Info.CalledName := CalledExpr;
      Info.SimpleName := SimpleName;
      Info.Line := N.Line;
      Results.Add(Info);
    end;

    // Second pass: parameterless dot-notation calls (no parentheses)
    // e.g. FAnimals[I].GetName appears as ntDot with right child ntIdentifier
    // When a call HAS parentheses, its ntDot node's parent will be ntCall,
    // which was already captured in the first pass.
    CollectNodes(StmtsNode, ntDot, DotNodes);
    for N in DotNodes do
    begin
      CalledExpr := ExprToSource(N);
      if CalledExpr = '' then
        Continue;

      // Extract the simple name (last part after dot)
      DotPos := LastDelimiter('.', CalledExpr);
      if DotPos > 0 then
        SimpleName := Copy(CalledExpr, DotPos + 1)
      else
        SimpleName := CalledExpr;

      Info.CalledName := CalledExpr;
      Info.SimpleName := SimpleName;
      Info.Line := N.Line;
      Results.Add(Info);
    end;

    Result := Results.ToArray;
  finally
    DotNodes.Free;
    CallNodes.Free;
    Results.Free;
  end;
end;

end.
