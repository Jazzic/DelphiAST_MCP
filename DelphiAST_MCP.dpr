program DelphiAST_MCP;

{$APPTYPE CONSOLE}


uses
  SysUtils,
  Classes,
  AST.Parser in 'AST.Parser.pas',
  AST.Query in 'AST.Query.pas',
  MCP.Tools in 'MCP.Tools.pas',
  MCP.Server in 'MCP.Server.pas';

var
  ProjectRoot: string;
  ExtraPaths: TArray<string>;
  Roots: TArray<string>;
  Port: Integer;
  Parser: TASTParser;
  Tools: TMCPTools;
  Server: TMCPServer;
  I, PathCount: Integer;
begin
  try
    // Defaults
    ProjectRoot := '';
    Port := 3000;
    PathCount := 0;

    // Parse arguments
    I := 1;
    while I <= ParamCount do
    begin
      if (ParamStr(I) = '--port') and (I < ParamCount) then
      begin
        Port := StrToIntDef(ParamStr(I + 1), 3000);
        Inc(I, 2);
      end
      else if (ParamStr(I) = '--path') and (I < ParamCount) then
      begin
        SetLength(ExtraPaths, PathCount + 1);
        ExtraPaths[PathCount] := ParamStr(I + 1);
        Inc(PathCount);
        Inc(I, 2);
      end
      else
      begin
        // First non-flag argument is project root
        if ProjectRoot = '' then
          ProjectRoot := ParamStr(I);
        Inc(I);
      end;
    end;

    if ProjectRoot = '' then
      ProjectRoot := GetCurrentDir;

    if not DirectoryExists(ProjectRoot) then
    begin
      WriteLn('Error: Directory not found: ' + ProjectRoot);
      ExitCode := 1;
      Exit;
    end;

    // Build roots array: project root first, then extra paths
    SetLength(Roots, 1 + PathCount);
    Roots[0] := ProjectRoot;
    for I := 0 to PathCount - 1 do
      Roots[I + 1] := ExtraPaths[I];

    WriteLn('Project root: ' + ProjectRoot);
    for I := 0 to PathCount - 1 do
      WriteLn('Extra path: ' + ExtraPaths[I]);

    Parser := TASTParser.Create(Roots);
    try
      Tools := TMCPTools.Create(Parser);
      try
        Server := TMCPServer.Create(Tools, Port);
        try
          Server.Run;
        finally
          Server.Free;
        end;
      finally
        Tools.Free;
      end;
    finally
      Parser.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('Fatal error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
