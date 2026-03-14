unit MCP.Tools;

interface

uses
  System.JSON, AST.Parser;

type
  TMCPTools = class
  private
    FParser: TASTParser;
  public
    constructor Create(AParser: TASTParser);

    function GetToolDefinitions: TJSONArray;
    function CallTool(const ToolName: string; Params: TJSONObject): TJSONValue;

    function DoListFiles(Params: TJSONObject): TJSONValue;
    function DoParseUnit(Params: TJSONObject): TJSONValue;
    function DoGetTypeDetail(Params: TJSONObject): TJSONValue;
    function DoGetMethodBody(Params: TJSONObject): TJSONValue;
    function DoFindReferences(Params: TJSONObject): TJSONValue;
    function DoGetUsesGraph(Params: TJSONObject): TJSONValue;
    function DoGetSyntaxTree(Params: TJSONObject): TJSONValue;
    function DoFindUsages(Params: TJSONObject): TJSONValue;
    function DoGetSource(Params: TJSONObject): TJSONValue;
    function DoSymbolAtPosition(Params: TJSONObject): TJSONValue;
    function DoResolveInheritance(Params: TJSONObject): TJSONValue;
    function DoGetCallGraph(Params: TJSONObject): TJSONValue;
    function DoSetProject(Params: TJSONObject): TJSONValue;
    function DoGetStatus(Params: TJSONObject): TJSONValue;
    function DoIsReady(Params: TJSONObject): TJSONValue;

    property Parser: TASTParser read FParser;
  end;

implementation

uses
  SysUtils, Classes, IOUtils, Generics.Collections, DelphiAST.Classes, DelphiAST.Consts, AST.Query;

{ TMCPTools }

constructor TMCPTools.Create(AParser: TASTParser);
begin
  inherited Create;
  FParser := AParser;
end;

function MakeInputSchema(Props: TJSONObject; const Required: array of string): TJSONObject;
var
  ReqArr: TJSONArray;
  S: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', Props);
  if Length(Required) > 0 then
  begin
    ReqArr := TJSONArray.Create;
    for S in Required do
      ReqArr.Add(S);
    Result.AddPair('required', ReqArr);
  end;
end;

function MakeStringProp(const Desc: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'string');
  Result.AddPair('description', Desc);
end;

function MakeIntProp(const Desc: string; Default: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'integer');
  Result.AddPair('description', Desc);
  Result.AddPair('default', TJSONNumber.Create(Default));
end;

function MakeBoolProp(const Desc: string; Default: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'boolean');
  Result.AddPair('description', Desc);
  Result.AddPair('default', TJSONBool.Create(Default));
end;

function MakeTool(const Name, Desc: string; Schema: TJSONObject): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('description', Desc);
  Result.AddPair('inputSchema', Schema);
end;

function TMCPTools.GetToolDefinitions: TJSONArray;
var
  Props: TJSONObject;
begin
  Result := TJSONArray.Create;

  // 1. list_files
  Props := TJSONObject.Create;
  Props.AddPair('filter', MakeStringProp('Optional filename filter substring'));
  Result.Add(MakeTool('list_files',
    'List all .pas/.dpr/.dpk files under the project root. Optional name filter.',
    MakeInputSchema(Props, [])));

  // 2. parse_unit
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file (relative to project root or absolute). If omitted, returns compact overviews for all parsed files.'));
  Result.Add(MakeTool('parse_unit',
    'Parse a Delphi file and return top-level structure: unit name, uses clauses, type names, constants, routine names with line numbers. If file is omitted, returns a project-wide map of all parsed units.',
    MakeInputSchema(Props, [])));

  // 3. get_type_detail
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file. If omitted, searches all parsed files for the type.'));
  Props.AddPair('type_name', MakeStringProp('Name of the type to inspect'));
  Result.Add(MakeTool('get_type_detail',
    'Detailed type info: fields, methods with parameter signatures, properties, inheritance, organized by visibility sections. If file is omitted, searches all project files.',
    MakeInputSchema(Props, ['type_name'])));

  // 4. get_method_body
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file. If omitted, searches all parsed files for the method.'));
  Props.AddPair('method_name', MakeStringProp('Name of the method (e.g. "TMyClass.DoSomething" or just "DoSomething")'));
  Result.Add(MakeTool('get_method_body',
    'Implementation body of a specific method as simplified statement-level AST (assignments, control flow, calls). If file is omitted, searches all project files.',
    MakeInputSchema(Props, ['method_name'])));

  // 5. find_references
  Props := TJSONObject.Create;
  Props.AddPair('pattern', MakeStringProp('Name pattern to search for (substring match, case-insensitive)'));
  Props.AddPair('kind', MakeStringProp('Optional filter: type, method, variable, or constant'));
  Props.AddPair('file', MakeStringProp('Optional: search only in this file. If omitted, searches all project files.'));
  Result.Add(MakeTool('find_references',
    'Search across project files for declarations matching a name pattern, filterable by kind (type/method/variable/constant).',
    MakeInputSchema(Props, ['pattern'])));

  // 6. get_uses_graph
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file'));
  Result.Add(MakeTool('get_uses_graph',
    'Unit dependency graph: what units a file uses (interface and implementation) and which project files use it.',
    MakeInputSchema(Props, ['file'])));

  // 7. get_syntax_tree
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file'));
  Props.AddPair('path', MakeStringProp('Optional path to a subtree (e.g. "interface/typesection/0"). Slash-separated, can use node type names or indices.'));
  Props.AddPair('max_depth', MakeIntProp('Maximum depth to traverse. 0 = unlimited.', 3));
  Result.Add(MakeTool('get_syntax_tree',
    'Raw AST subtree as compact JSON. Compact keys: t=type, a=attributes, l=line, c=children, v=value. Use for detailed analysis.',
    MakeInputSchema(Props, ['file'])));

  // 8. find_usages
  Props := TJSONObject.Create;
  Props.AddPair('name', MakeStringProp('Identifier name to search for (exact match, case-insensitive)'));
  Props.AddPair('file', MakeStringProp('Optional: search only in this file. If omitted, searches all project files.'));
  Props.AddPair('include_declarations', MakeBoolProp('Include declaration sites in results. Default true.', True));
  Result.Add(MakeTool('find_usages',
    'Find all usage sites of an identifier (calls, reads, writes, type references, declarations). Unlike find_references which finds declarations only, this finds everywhere an identifier is actually used.',
    MakeInputSchema(Props, ['name'])));

  // 9. get_source
  Props := TJSONObject.Create;
  Props.AddPair('symbol', MakeStringProp('Symbol name to get source for (e.g. "TMyClass.DoSomething"). Mutually exclusive with start_line/end_line.'));
  Props.AddPair('file', MakeStringProp('Path to the file. Required for line-range mode, optional for symbol mode.'));
  Props.AddPair('start_line', MakeIntProp('Start line number (1-based). Used with end_line for line-range mode.', 0));
  Props.AddPair('end_line', MakeIntProp('End line number (1-based, inclusive). Used with start_line for line-range mode.', 0));
  Result.Add(MakeTool('get_source',
    'Return actual source code for a symbol or line range. Unlike get_method_body which returns simplified AST, this returns the real Delphi source text.',
    MakeInputSchema(Props, [])));

  // 10. symbol_at_position
  Props := TJSONObject.Create;
  Props.AddPair('file', MakeStringProp('Path to the file'));
  Props.AddPair('line', MakeIntProp('Line number (1-based)', 0));
  Props.AddPair('col', MakeIntProp('Column number (1-based)', 0));
  Result.Add(MakeTool('symbol_at_position',
    'Find the AST node at a specific file position. Returns node type, name, qualified name, and enclosing method/type context.',
    MakeInputSchema(Props, ['file', 'line', 'col'])));

  // 11. resolve_inheritance
  Props := TJSONObject.Create;
  Props.AddPair('type_name', MakeStringProp('Type to resolve (e.g. "TMyClass")'));
  Props.AddPair('max_depth', MakeIntProp('Max chain depth. Default 20.', 20));
  Result.Add(MakeTool('resolve_inheritance',
    'Walk the inheritance chain of a type across all parsed units. Returns full type detail at each level, resolving ancestors into other project files. Unresolved types (external/VCL) get a stub with resolved=false.',
    MakeInputSchema(Props, ['type_name'])));

  // 12. get_call_graph
  Props := TJSONObject.Create;
  Props.AddPair('method_name', MakeStringProp('Method to analyze (e.g. "TMyClass.DoSomething")'));
  Props.AddPair('direction', MakeStringProp('Direction: "callees" (default) shows what this method calls, "callers" shows what calls it'));
  Props.AddPair('depth', MakeIntProp('Recursion depth for multi-level graphs. Default 1, max 10.', 1));
  Result.Add(MakeTool('get_call_graph',
    'Analyze method call relationships. "callees" mode extracts all calls from a method body. "callers" mode finds all methods that call the target. Supports multi-level recursion with cycle detection.',
    MakeInputSchema(Props, ['method_name'])));

  // 13. set_project
  Props := TJSONObject.Create;
  Props.AddPair('path', MakeStringProp('Absolute path to the project root directory'));
  Result.Add(MakeTool('set_project',
    'Set the project root directory. Reads .delphi-ast.json for library paths. ' +
    'Call this before using other tools to point the server at your project.',
    MakeInputSchema(Props, ['path'])));

  // 14. get_status
  Props := TJSONObject.Create;
  Result.Add(MakeTool('get_status',
    'Returns the current parse state of the server. ' +
    'State is "idle" when ready, "parsing" while background parse is running. ' +
    'Includes total_files, cached_files, parsed_files, and failed_files counts.',
    MakeInputSchema(Props, [])));

  // 15. is_ready
  Props := TJSONObject.Create;
  Result.Add(MakeTool('is_ready',
    'Returns {"ready": true} when the server has finished parsing and is ready to serve requests, ' +
    '"{"ready": false} otherwise. Use this after set_project to wait for parsing to complete.',
    MakeInputSchema(Props, [])));
end;

function TMCPTools.CallTool(const ToolName: string; Params: TJSONObject): TJSONValue;
begin
  // Allow status/project tools through always; guard others against bad state
  if (ToolName <> 'get_status') and (ToolName <> 'set_project') and (ToolName <> 'is_ready') then
  begin
    if not FParser.IsConfigured then
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error',
        'No project configured. Call set_project first.');
      Exit;
    end;

    if not FParser.IsReady then
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error',
        'Server is still parsing. Use get_status to check progress.');
      Exit;
    end;
  end;

  try
    if ToolName = 'get_status' then
      Result := DoGetStatus(Params)
    else if ToolName = 'is_ready' then
      Result := DoIsReady(Params)
    else if ToolName = 'list_files' then
      Result := DoListFiles(Params)
    else if ToolName = 'parse_unit' then
      Result := DoParseUnit(Params)
    else if ToolName = 'get_type_detail' then
      Result := DoGetTypeDetail(Params)
    else if ToolName = 'get_method_body' then
      Result := DoGetMethodBody(Params)
    else if ToolName = 'find_references' then
      Result := DoFindReferences(Params)
    else if ToolName = 'get_uses_graph' then
      Result := DoGetUsesGraph(Params)
    else if ToolName = 'get_syntax_tree' then
      Result := DoGetSyntaxTree(Params)
    else if ToolName = 'find_usages' then
      Result := DoFindUsages(Params)
    else if ToolName = 'get_source' then
      Result := DoGetSource(Params)
    else if ToolName = 'symbol_at_position' then
      Result := DoSymbolAtPosition(Params)
    else if ToolName = 'resolve_inheritance' then
      Result := DoResolveInheritance(Params)
    else if ToolName = 'get_call_graph' then
      Result := DoGetCallGraph(Params)
    else if ToolName = 'set_project' then
      Result := DoSetProject(Params)
    else
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error', 'Unknown tool: ' + ToolName);
    end;
  except
    on E: Exception do
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error', E.Message);
    end;
  end;
end;

function GetStr(Params: TJSONObject; const Key: string; const Default: string = ''): string;
var
  V: TJSONValue;
begin
  if (Params <> nil) and Params.TryGetValue(Key, V) then
    Result := V.Value
  else
    Result := Default;
end;

function GetInt(Params: TJSONObject; const Key: string; Default: Integer): Integer;
var
  V: TJSONValue;
begin
  if (Params <> nil) and Params.TryGetValue(Key, V) then
  begin
    if V is TJSONNumber then
      Result := TJSONNumber(V).AsInt
    else if not TryStrToInt(V.Value, Result) then
      Result := Default;
  end
  else
    Result := Default;
end;

function TMCPTools.DoListFiles(Params: TJSONObject): TJSONValue;
var
  Filter: string;
  Files: TArray<string>;
  Arr: TJSONArray;
  F: string;
begin
  try
    Filter := GetStr(Params, 'filter');
    Files := FParser.ListFiles(Filter);
    Arr := TJSONArray.Create;
    for F in Files do
      Arr.Add(F);
    Result := Arr;
  except
    on E: Exception do
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error', E.Message);
    end;
  end;
end;

function TMCPTools.DoParseUnit(Params: TJSONObject): TJSONValue;
var
  FileName: string;
  Tree: TSyntaxNode;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  Arr: TJSONArray;
  Overview, Item: TJSONObject;
  TypeCount, RoutineCount: Integer;
begin
  FileName := GetStr(Params, 'file');

  if FileName <> '' then
  begin
    Tree := FParser.ParseFile(FileName);
    Result := ExtractUnitOverview(Tree);
  end
  else
  begin
    // Return compact overviews for all parsed files
    AllTrees := FParser.GetAllTrees;
    Arr := TJSONArray.Create;
    for Pair in AllTrees do
    begin
      try
        Overview := ExtractUnitOverview(Pair.Value);
        try
          Item := TJSONObject.Create;
          Item.AddPair('file', Pair.Key);
          if Overview.FindValue('name') <> nil then
            Item.AddPair('name', Overview.FindValue('name').Clone as TJSONValue);

          // Count types and routines from the overview
          TypeCount := 0;
          RoutineCount := 0;
          if Overview.FindValue('types') is TJSONArray then
            TypeCount := TJSONArray(Overview.FindValue('types')).Count;
          if Overview.FindValue('routines') is TJSONArray then
            RoutineCount := TJSONArray(Overview.FindValue('routines')).Count;

          Item.AddPair('types', TJSONNumber.Create(TypeCount));
          Item.AddPair('routines', TJSONNumber.Create(RoutineCount));
          Arr.Add(Item);
        finally
          Overview.Free;
        end;
      except
        // Skip files that fail
      end;
    end;
    Result := Arr;
  end;
end;

function TMCPTools.DoGetTypeDetail(Params: TJSONObject): TJSONValue;
var
  FileName, TypeName: string;
  Tree: TSyntaxNode;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  Detail: TJSONObject;
begin
  FileName := GetStr(Params, 'file');
  TypeName := GetStr(Params, 'type_name');

  if FileName <> '' then
  begin
    Tree := FParser.ParseFile(FileName);
    Result := ExtractTypeDetail(Tree, TypeName);
  end
  else
  begin
    // Search all cached trees for the type
    AllTrees := FParser.GetAllTrees;
    for Pair in AllTrees do
    begin
      Detail := ExtractTypeDetail(Pair.Value, TypeName);
      if (Detail.FindValue('error') = nil) then
      begin
        Detail.AddPair('file', Pair.Key);
        Result := Detail;
        Exit;
      end;
      Detail.Free;
    end;
    Result := TJSONObject.Create;
    TJSONObject(Result).AddPair('error', 'Type "' + TypeName + '" not found');
  end;
end;

function TMCPTools.DoGetMethodBody(Params: TJSONObject): TJSONValue;
var
  FileName, MethodName: string;
  Tree: TSyntaxNode;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  Body: TJSONObject;
begin
  FileName := GetStr(Params, 'file');
  MethodName := GetStr(Params, 'method_name');

  if FileName <> '' then
  begin
    Tree := FParser.ParseFile(FileName);
    Result := ExtractMethodBody(Tree, MethodName);
  end else
  begin
    // Search all cached trees for the method
    AllTrees := FParser.GetAllTrees;
    for Pair in AllTrees do
    begin
      Assert(Assigned(Pair.Value), 'Tree not assigned for ' + Pair.Key);
      Body := ExtractMethodBody(Pair.Value, MethodName);
      // Check if the result actually found the method (has a 'name' field)
      if (Body.FindValue('error') = nil) then
      begin
        Body.AddPair('file', Pair.Key);
        Result := Body;
        Exit;
      end;
      Body.Free;
    end;
    Result := TJSONObject.Create;
    TJSONObject(Result).AddPair('error', 'Method not found: ' + MethodName);
    Exit;
  end;
end;

function TMCPTools.DoFindReferences(Params: TJSONObject): TJSONValue;
var
  Pattern, Kind, SingleFile: string;
  Tree: TSyntaxNode;
  AllResults, FileResults: TJSONArray;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  I: Integer;
begin
  Pattern := GetStr(Params, 'pattern');
  Kind := GetStr(Params, 'kind');
  SingleFile := GetStr(Params, 'file');

  AllResults := TJSONArray.Create;

  if SingleFile <> '' then
  begin
    Tree := FParser.ParseFile(SingleFile);
    FileResults := FindReferences(Tree, SingleFile, Pattern, Kind);
    try
      for I := 0 to FileResults.Count - 1 do
        AllResults.AddElement(TJSONValue(FileResults.Items[I].Clone));
    finally
      FileResults.Free;
    end;
  end
  else
  begin
    AllTrees := FParser.GetAllTrees;
    for Pair in AllTrees do
    begin
      try
        FileResults := FindReferences(Pair.Value, Pair.Key, Pattern, Kind);
        try
          for I := 0 to FileResults.Count - 1 do
            AllResults.AddElement(TJSONValue(FileResults.Items[I].Clone));
        finally
          FileResults.Free;
        end;
      except
        // Skip files that fail
      end;
    end;
  end;

  Result := AllResults;
end;

function TMCPTools.DoGetUsesGraph(Params: TJSONObject): TJSONValue;
var
  FileName, UnitName: string;
  Tree: TSyntaxNode;
  GraphObj: TJSONObject;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  IntfNode, ImplNode, UsesNode, Child: TSyntaxNode;
  UsedBy: TJSONArray;
begin
  FileName := GetStr(Params, 'file');
  Tree := FParser.ParseFile(FileName);

  UnitName := Tree.GetAttribute(anName);
  if UnitName = '' then
    UnitName := ChangeFileExt(ExtractFileName(FileName), '');

  GraphObj := ExtractUsesGraph(Tree, UnitName);

  // Find which project files use this unit
  UsedBy := TJSONArray.Create;
  AllTrees := FParser.GetAllTrees;
  for Pair in AllTrees do
  begin
    if SameText(Pair.Key, LowerCase(FParser.ResolveFilePath(FileName))) then
      Continue;
    try
      IntfNode := Pair.Value.FindNode(ntInterface);
      ImplNode := Pair.Value.FindNode(ntImplementation);

      // Check interface uses
      if IntfNode <> nil then
      begin
        UsesNode := IntfNode.FindNode(ntUses);
        if UsesNode <> nil then
          for Child in UsesNode.ChildNodes do
            if SameText(Child.GetAttribute(anName), UnitName) then
            begin
              UsedBy.Add(Pair.Key);
              Break;
            end;
      end;

      // Check implementation uses
      if ImplNode <> nil then
      begin
        UsesNode := ImplNode.FindNode(ntUses);
        if UsesNode <> nil then
          for Child in UsesNode.ChildNodes do
            if SameText(Child.GetAttribute(anName), UnitName) then
            begin
              // Avoid duplicate
              var AlreadyAdded := False;
              var J: Integer;
              for J := 0 to UsedBy.Count - 1 do
                if SameText(UsedBy.Items[J].Value, Pair.Key) then
                begin
                  AlreadyAdded := True;
                  Break;
                end;
              if not AlreadyAdded then
                UsedBy.Add(Pair.Key);
              Break;
            end;
      end;
    except
      // Skip files that fail
    end;
  end;

  if UsedBy.Count > 0 then
    GraphObj.AddPair('used_by', UsedBy)
  else
    UsedBy.Free;

  Result := GraphObj;
end;

function TMCPTools.DoGetSyntaxTree(Params: TJSONObject): TJSONValue;
var
  FileName, Path: string;
  MaxDepth: Integer;
  Tree: TSyntaxNode;
begin
  FileName := GetStr(Params, 'file');
  Path := GetStr(Params, 'path');
  MaxDepth := GetInt(Params, 'max_depth', 3);
  Tree := FParser.ParseFile(FileName);
  Result := ExtractSyntaxTree(Tree, Path, MaxDepth);
end;

function GetBool(Params: TJSONObject; const Key: string; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  if (Params <> nil) and Params.TryGetValue(Key, V) then
  begin
    if V is TJSONBool then
      Result := TJSONBool(V).AsBoolean
    else
      Result := SameText(V.Value, 'true');
  end
  else
    Result := Default;
end;

function TMCPTools.DoFindUsages(Params: TJSONObject): TJSONValue;
var
  IdentName, SingleFile: string;
  IncludeDecls: Boolean;
  Tree: TSyntaxNode;
  AllResults, FileResults: TJSONArray;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  I: Integer;
  Item: TJSONObject;
  Context: string;
begin
  IdentName := GetStr(Params, 'name');
  SingleFile := GetStr(Params, 'file');
  IncludeDecls := GetBool(Params, 'include_declarations', True);

  AllResults := TJSONArray.Create;

  if SingleFile <> '' then
  begin
    Tree := FParser.ParseFile(SingleFile);
    FileResults := FindUsages(Tree, SingleFile, IdentName);
    try
      for I := 0 to FileResults.Count - 1 do
      begin
        if not IncludeDecls then
        begin
          Item := FileResults.Items[I] as TJSONObject;
          Context := '';
          if Item.TryGetValue<string>('context', Context) then
            if Context = 'declaration' then
              Continue;
        end;
        AllResults.AddElement(TJSONValue(FileResults.Items[I].Clone));
      end;
    finally
      FileResults.Free;
    end;
  end
  else
  begin
    AllTrees := FParser.GetAllTrees;
    for Pair in AllTrees do
    begin
      try
        FileResults := FindUsages(Pair.Value, Pair.Key, IdentName);
        try
          for I := 0 to FileResults.Count - 1 do
          begin
            if not IncludeDecls then
            begin
              Item := FileResults.Items[I] as TJSONObject;
              Context := '';
              if Item.TryGetValue<string>('context', Context) then
                if Context = 'declaration' then
                  Continue;
            end;
            AllResults.AddElement(TJSONValue(FileResults.Items[I].Clone));
          end;
        finally
          FileResults.Free;
        end;
      except
        // Skip files that fail
      end;
    end;
  end;

  Result := AllResults;
end;

function TMCPTools.DoGetSource(Params: TJSONObject): TJSONValue;
var
  SymbolName, FileName: string;
  StartLine, EndLine: Integer;
  Tree: TSyntaxNode;
  Loc: TSymbolLocation;
  Lines: TStringList;
  FullPath: string;
  Obj: TJSONObject;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Pair: TPair<string, TSyntaxNode>;
  SourceLines: TStringList;
  I: Integer;
begin
  SymbolName := GetStr(Params, 'symbol');
  FileName := GetStr(Params, 'file');
  StartLine := GetInt(Params, 'start_line', 0);
  EndLine := GetInt(Params, 'end_line', 0);

  // Mode 1: by symbol name
  if SymbolName <> '' then
  begin
    if FileName <> '' then
    begin
      Tree := FParser.ParseFile(FileName);
      Loc := LocateSymbol(Tree, SymbolName);
      if not Loc.Found then
      begin
        Result := TJSONObject.Create;
        TJSONObject(Result).AddPair('error', Format('Symbol "%s" not found in %s', [SymbolName, FileName]));
        Exit;
      end;
      FullPath := FParser.ResolveFilePath(FileName);
    end
    else
    begin
      // Search all cached trees
      Loc.Found := False;
      FullPath := '';
      AllTrees := FParser.GetAllTrees;
      for Pair in AllTrees do
      begin
        try
          Loc := LocateSymbol(Pair.Value, SymbolName);
          if Loc.Found then
          begin
            FullPath := Pair.Key;
            FileName := Pair.Key;
            Break;
          end;
        except
        end;
      end;
      if not Loc.Found then
      begin
        Result := TJSONObject.Create;
        TJSONObject(Result).AddPair('error', Format('Symbol "%s" not found in any parsed file', [SymbolName]));
        Exit;
      end;
    end;

    StartLine := Loc.StartLine;
    EndLine := Loc.EndLine;
  end
  else
  begin
    // Mode 2: by explicit line range
    if FileName = '' then
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error', 'Either "symbol" or "file" with "start_line"/"end_line" is required');
      Exit;
    end;
    if (StartLine <= 0) or (EndLine <= 0) then
    begin
      Result := TJSONObject.Create;
      TJSONObject(Result).AddPair('error', 'Both "start_line" and "end_line" are required in line-range mode');
      Exit;
    end;
    FullPath := FParser.ResolveFilePath(FileName);
  end;

  // Read file and extract lines
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FullPath);

    if StartLine < 1 then StartLine := 1;
    if EndLine > Lines.Count then EndLine := Lines.Count;

    SourceLines := TStringList.Create;
    try
      for I := StartLine - 1 to EndLine - 1 do
        SourceLines.Add(Lines[I]);

      Obj := TJSONObject.Create;
      Obj.AddPair('file', FileName);
      Obj.AddPair('start_line', TJSONNumber.Create(StartLine));
      Obj.AddPair('end_line', TJSONNumber.Create(EndLine));
      if SymbolName <> '' then
      begin
        Obj.AddPair('symbol', Loc.Name);
        Obj.AddPair('kind', Loc.Kind);
      end;
      Obj.AddPair('source', SourceLines.Text);
      Result := Obj;
    finally
      SourceLines.Free;
    end;
  finally
    Lines.Free;
  end;
end;

function TMCPTools.DoSymbolAtPosition(Params: TJSONObject): TJSONValue;
var
  FileName: string;
  Line, Col: Integer;
  Tree: TSyntaxNode;
begin
  FileName := GetStr(Params, 'file');
  Line := GetInt(Params, 'line', 0);
  Col := GetInt(Params, 'col', 0);

  Tree := FParser.ParseFile(FileName);
  Result := SymbolAtPosition(Tree, Line, Col);

  // Add file info to result
  if Result is TJSONObject then
    TJSONObject(Result).AddPair('file', FileName);
end;

function TMCPTools.DoResolveInheritance(Params: TJSONObject): TJSONValue;
var
  TypeName: string;
  MaxDepth: Integer;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  Chain: TJSONArray;
  Visited: TStringList;
  Complete: Boolean;
  ResultObj: TJSONObject;

  procedure ResolveType(const ATypeName: string; Depth: Integer);
  var
    Pair: TPair<string, TSyntaxNode>;
    Detail: TJSONObject;
    Ancestors: TArray<string>;
    AncName: string;
    Found: Boolean;
  begin
    if Depth > MaxDepth then
    begin
      Complete := False;
      Exit;
    end;

    if Visited.IndexOf(LowerCase(ATypeName)) >= 0 then
      Exit; // Circular reference
    Visited.Add(LowerCase(ATypeName));

    Found := False;
    for Pair in AllTrees do
    begin
      try
        Assert(Assigned(Pair.Value), 'Tree not assigned for ' + Pair.Key);
        Detail := ExtractTypeDetail(Pair.Value, ATypeName);
        if (Detail.FindValue('name') <> nil) and
           (Detail.FindValue('name').Value <> '') and
           (Detail.FindValue('error') = nil) then
        begin
          Detail.AddPair('file', Pair.Key);
          Detail.AddPair('resolved', TJSONBool.Create(True));

          // Get ancestor names for recursion
          Ancestors := ExtractAncestorNames(Pair.Value, ATypeName);

          // Add ancestors array if not already present
          if (Detail.FindValue('ancestors') = nil) and (Length(Ancestors) > 0) then
          begin
            var AncArr := TJSONArray.Create;
            for AncName in Ancestors do
              AncArr.Add(AncName);
            Detail.AddPair('ancestors', AncArr);
          end;

          Chain.Add(Detail);
          Found := True;

          // Recurse into each ancestor
          for AncName in Ancestors do
            ResolveType(AncName, Depth + 1);

          Break;
        end
        else
          Detail.Free;
      except
        // Skip files that fail
      end;
    end;

    if not Found then
    begin
      // Unresolved type stub
      var Stub := TJSONObject.Create;
      Stub.AddPair('name', ATypeName);
      Stub.AddPair('resolved', TJSONBool.Create(False));
      Chain.Add(Stub);
      Complete := False;
    end;
  end;

begin
  TypeName := GetStr(Params, 'type_name');
  MaxDepth := GetInt(Params, 'max_depth', 20);

  AllTrees := FParser.GetAllTrees;
  Chain := TJSONArray.Create;
  Visited := TStringList.Create;
  Visited.CaseSensitive := False;
  Complete := True;

  try
    ResolveType(TypeName, 1);

    if Chain.Count = 0 then
    begin
      Chain.Free;
      ResultObj := TJSONObject.Create;
      ResultObj.AddPair('error', Format('Type "%s" not found in any parsed file', [TypeName]));
      Result := ResultObj;
      Exit;  // finally block will free Visited — no double-free
    end;

    // Check if the queried type itself was not found (first item is an unresolved stub)
    // If so, add an error field to the result
    if Chain.Count > 0 then
    begin
      var FirstVal := Chain.Items[0];
      if (FirstVal <> nil) and (FirstVal is TJSONObject) then
      begin
        var FirstItem := TJSONObject(FirstVal);
        if (FirstItem.FindValue('resolved') <> nil) and
           not FirstItem.GetValue<Boolean>('resolved') then
        begin
          // The queried type was not found - add error field
          ResultObj := TJSONObject.Create;
          ResultObj.AddPair('error', 'Type "' + TypeName + '" not found in any parsed file');
          ResultObj.AddPair('type_name', TypeName);
          ResultObj.AddPair('chain', Chain);
          ResultObj.AddPair('depth', TJSONNumber.Create(Chain.Count));
          ResultObj.AddPair('complete', TJSONBool.Create(Complete));
          Result := ResultObj;
          Exit;
        end;
      end;
    end;

    ResultObj := TJSONObject.Create;
    ResultObj.AddPair('type_name', TypeName);
    ResultObj.AddPair('chain', Chain);
    ResultObj.AddPair('depth', TJSONNumber.Create(Chain.Count));
    ResultObj.AddPair('complete', TJSONBool.Create(Complete));
    Result := ResultObj;
  finally
    Visited.Free;
  end;
end;

function TMCPTools.DoGetCallGraph(Params: TJSONObject): TJSONValue;
var
  MethodName, Direction: string;
  Depth: Integer;
  AllTrees: TArray<TPair<string, TSyntaxNode>>;
  ResultObj: TJSONObject;

  function FindMethodFile(const AMethodName: string; out FoundFile: string;
    out FoundTree: TSyntaxNode): Boolean;
  var
    Pair: TPair<string, TSyntaxNode>;
    Body: TJSONObject;
  begin
    Result := False;
    for Pair in AllTrees do
    begin
      try
        Body := ExtractMethodBody(Pair.Value, AMethodName);
        try
          if (Body.FindValue('name') <> nil) and
             (Body.FindValue('name').Value <> '') and
             (Body.FindValue('error') = nil) then
          begin
            FoundFile := Pair.Key;
            FoundTree := Pair.Value;
            Exit(True);
          end;
        finally
          Body.Free;
        end;
      except
      end;
    end;
  end;

  procedure CollectCallees(const AMethodName: string; CurrentDepth: Integer;
    Visited: TStringList; CallsArr: TJSONArray);
  var
    FoundFile: string;
    FoundTree: TSyntaxNode;
    Calls: TArray<TCallInfo>;
    CI: TCallInfo;
    CallObj: TJSONObject;
    ResolvedFile: string;
    ResolvedTree: TSyntaxNode;
  begin
    if CurrentDepth > Depth then Exit;
    if Visited.IndexOf(LowerCase(AMethodName)) >= 0 then Exit;
    Visited.Add(LowerCase(AMethodName));

    if not FindMethodFile(AMethodName, FoundFile, FoundTree) then
      Exit;

    Calls := ExtractCallsFromMethod(FoundTree, AMethodName);
    for CI in Calls do
    begin
      CallObj := TJSONObject.Create;
      CallObj.AddPair('name', CI.CalledName);
      CallObj.AddPair('line', TJSONNumber.Create(CI.Line));

      // Try to resolve the call target
      if FindMethodFile(CI.SimpleName, ResolvedFile, ResolvedTree) then
        CallObj.AddPair('resolved_in', ResolvedFile)
      else
        CallObj.AddPair('resolved', TJSONBool.Create(False));

      CallsArr.Add(CallObj);

      // Recurse if depth allows
      if (CurrentDepth < Depth) and (Visited.IndexOf(LowerCase(CI.SimpleName)) < 0) then
      begin
        if FindMethodFile(CI.SimpleName, ResolvedFile, ResolvedTree) then
        begin
          var SubCalls := TJSONArray.Create;
          CollectCallees(CI.SimpleName, CurrentDepth + 1, Visited, SubCalls);
          if SubCalls.Count > 0 then
            CallObj.AddPair('calls', SubCalls)
          else
            SubCalls.Free;
        end;
      end;
    end;
  end;

  procedure CollectCallers(const AMethodName: string; CurrentDepth: Integer;
    Visited: TStringList; CallersArr: TJSONArray);
  var
    Pair: TPair<string, TSyntaxNode>;
    MName, SimpleTarget: string;
    Calls: TArray<TCallInfo>;
    CI: TCallInfo;
    CallerObj: TJSONObject;
    DotPos, I: Integer;
    MethodRefs: TJSONArray;
    RefObj: TJSONObject;
  begin
    if CurrentDepth > Depth then Exit;
    if Visited.IndexOf(LowerCase(AMethodName)) >= 0 then Exit;
    Visited.Add(LowerCase(AMethodName));

    // Extract simple name from target
    DotPos := LastDelimiter('.', AMethodName);
    if DotPos > 0 then
      SimpleTarget := Copy(AMethodName, DotPos + 1)
    else
      SimpleTarget := AMethodName;

    for Pair in AllTrees do
    begin
      // Use FindReferences to get all method declarations in this file
      MethodRefs := FindReferences(Pair.Value, Pair.Key, '', 'method');
      try
        for I := 0 to MethodRefs.Count - 1 do
        begin
          RefObj := MethodRefs.Items[I] as TJSONObject;
          MName := RefObj.GetValue<string>('name', '');
          if MName = '' then Continue;

          // Don't check the method against itself
          if SameText(MName, AMethodName) then Continue;

          Calls := ExtractCallsFromMethod(Pair.Value, MName);
          for CI in Calls do
          begin
            if SameText(CI.SimpleName, SimpleTarget) then
            begin
              CallerObj := TJSONObject.Create;
              CallerObj.AddPair('name', MName);
              CallerObj.AddPair('file', Pair.Key);
              CallerObj.AddPair('line', TJSONNumber.Create(RefObj.GetValue<Integer>('line', 0)));
              CallersArr.Add(CallerObj);

              // Recurse if depth allows
              if (CurrentDepth < Depth) and (Visited.IndexOf(LowerCase(MName)) < 0) then
              begin
                var SubCallers := TJSONArray.Create;
                CollectCallers(MName, CurrentDepth + 1, Visited, SubCallers);
                if SubCallers.Count > 0 then
                  CallerObj.AddPair('callers', SubCallers)
                else
                  SubCallers.Free;
              end;

              Break; // Found this method is a caller, move to next method
            end;
          end;
        end;
      finally
        MethodRefs.Free;
      end;
    end;
  end;

var
  FoundFile: string;
  FoundTree: TSyntaxNode;
  Visited: TStringList;
begin
  MethodName := GetStr(Params, 'method_name');
  Direction := GetStr(Params, 'direction', 'callees');
  Depth := GetInt(Params, 'depth', 1);

  // Clamp depth
  if Depth < 1 then Depth := 1;
  if Depth > 10 then Depth := 10;

  AllTrees := FParser.GetAllTrees;

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('method', MethodName);
  ResultObj.AddPair('direction', Direction);
  ResultObj.AddPair('depth', TJSONNumber.Create(Depth));

  Visited := TStringList.Create;
  Visited.CaseSensitive := False;
  try
    if SameText(Direction, 'callers') then
    begin
      var CallersArr := TJSONArray.Create;
      CollectCallers(MethodName, 1, Visited, CallersArr);
      ResultObj.AddPair('callers', CallersArr);
    end
    else
    begin
      // Default: callees
      if FindMethodFile(MethodName, FoundFile, FoundTree) then
        ResultObj.AddPair('file', FoundFile)
      else
      begin
        ResultObj.AddPair('error', Format('Method "%s" not found in any parsed file', [MethodName]));
        Result := ResultObj;
        Exit;  // finally block will free Visited — no double-free
      end;

      var CallsArr := TJSONArray.Create;
      CollectCallees(MethodName, 1, Visited, CallsArr);
      ResultObj.AddPair('calls', CallsArr);
    end;

    Result := ResultObj;
  finally
    Visited.Free;
  end;
end;

function IsSkippableDir(const DirName: string): Boolean;
begin
  Result := DirName.StartsWith('.') or
            DirName.StartsWith('__') or
            SameText(DirName, 'dcu64') or
            SameText(DirName, 'dcu32') or
            SameText(DirName, 'bin64') or
            SameText(DirName, 'bin32');
end;

function ExpandWithSubdirs(const Paths: TArray<string>): TArray<string>;
var
  Path, Sub: string;
  Subs: TArray<string>;
  Skip: Boolean;
  Parts: TArray<string>;
  Part: string;
begin
  Result := nil;
  for Path in Paths do
  begin
    if not DirectoryExists(Path) then
      Continue;
    Result := Result + [Path];
    Subs := TDirectory.GetDirectories(Path, '*', TSearchOption.soAllDirectories);
    for Sub in Subs do
    begin
      // Check if any path component should be skipped
      Skip := False;
      Parts := Sub.Substring(Path.Length + 1).Split(['\', '/']);
      for Part in Parts do
        if IsSkippableDir(Part) then
        begin
          Skip := True;
          Break;
        end;
      if not Skip then
        Result := Result + [Sub];
    end;
  end;
end;

function TMCPTools.DoSetProject(Params: TJSONObject): TJSONValue;
var
  ProjectPath, ConfigFile, ConfigText: string;
  ConfigJSON, LibPathsObj: TJSONValue;
  LibPathsArr: TJSONArray;
  Roots: TArray<string>;
  I: Integer;
  ResultObj: TJSONObject;
begin
  ProjectPath := GetStr(Params, 'path');
  if ProjectPath = '' then
  begin
    Result := TJSONObject.Create;
    TJSONObject(Result).AddPair('error', 'path is required');
    Exit;
  end;
  if not DirectoryExists(ProjectPath) then
  begin
    Result := TJSONObject.Create;
    TJSONObject(Result).AddPair('error', 'Directory not found: ' + ProjectPath);
    Exit;
  end;

  // Normalize the project path to resolve any .. or . components
  ProjectPath := ExpandFileName(ProjectPath);

  // Start with project root
  SetLength(Roots, 1);
  Roots[0] := ProjectPath;

  // Read .delphi-ast.json if present
  ConfigFile := TPath.Combine(ProjectPath, '.delphi-ast.json');
  if FileExists(ConfigFile) then
  begin
    ConfigText := TFile.ReadAllText(ConfigFile);
    ConfigJSON := TJSONObject.ParseJSONValue(ConfigText);
    try
      if (ConfigJSON is TJSONObject) and
         TJSONObject(ConfigJSON).TryGetValue('libraryPaths', LibPathsObj) and
         (LibPathsObj is TJSONArray) then
      begin
        LibPathsArr := TJSONArray(LibPathsObj);
        for I := 0 to LibPathsArr.Count - 1 do
        begin
          SetLength(Roots, Length(Roots) + 1);
          // Normalize library paths as well
          Roots[High(Roots)] := ExpandFileName(LibPathsArr.Items[I].Value);
        end;
      end;
    finally
      ConfigJSON.Free;
    end;
  end;

  // Expand each root to include all subdirectories recursively
  Roots := ExpandWithSubdirs(Roots);

  // Reconfigure parser with new roots
  FParser.Reconfigure(Roots);

  // Return result
  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('project', ProjectPath);
  ResultObj.AddPair('files', TJSONNumber.Create(Length(FParser.ListFiles(''))));
  // Include library paths in response
  LibPathsArr := TJSONArray.Create;
  for I := 1 to High(Roots) do
    LibPathsArr.Add(Roots[I]);
  ResultObj.AddPair('libraryPaths', LibPathsArr);
  Result := ResultObj;
end;

function TMCPTools.DoGetStatus(Params: TJSONObject): TJSONValue;
var
  Status: TParseStatus;
  Obj: TJSONObject;
begin
  Status := FParser.GetParseStatus;
  Obj := TJSONObject.Create;
  if Status.State = psIdle then
    Obj.AddPair('state', 'idle')
  else
    Obj.AddPair('state', 'parsing');
  Obj.AddPair('total_files', TJSONNumber.Create(Status.TotalFiles));
  Obj.AddPair('cached_files', TJSONNumber.Create(Status.CachedFiles));
  Obj.AddPair('parsed_files', TJSONNumber.Create(Status.ParsedFiles));
  Obj.AddPair('failed_files', TJSONNumber.Create(Status.FailedFiles));
  Result := Obj;
end;

function TMCPTools.DoIsReady(Params: TJSONObject): TJSONValue;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('ready', TJSONBool.Create(FParser.IsReady));
  Result := Obj;
end;

end.
