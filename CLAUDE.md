# DelphiAST MCP Server

## Building

Use the batch files in the project root:

Build MCP server:
```bash
c:\Users\jespe\Documents\Embarcadero\Studio\Projects\DelphiAST_MCP\build.bat 
```

Build test suite:
```bash
c:\Users\jespe\Documents\Embarcadero\Studio\Projects\DelphiAST_MCP\build-tests.bat 
```

Run the tests:
```bash
c:\Users\jespe\Documents\Embarcadero\Studio\Projects\DelphiAST_MCP\run-tests.bat 
```


## Architecture

- **5 units**: AST.Parser, AST.Query, MCP.Tools, MCP.Server, DelphiAST_MCP.dpr
- **7 MCP tools**: list_files, parse_unit, get_type_detail, get_method_body, find_references, get_uses_graph, get_syntax_tree
- Newline-delimited JSON-RPC 2.0 over stdio, protocol version `2024-11-05`
- AST caching via `TObjectDictionary<string, TSyntaxNode>`

## DelphiAST Library Notes

- Field/variable/parameter names stored as `TValuedSyntaxNode` children with `ntName` type (use `.Value`, not `.GetAttribute(anName)`)
- Property read/write accessors stored as `ntIdentifier` children of `ntRead`/`ntWrite` nodes
- Use `TUTF8Encoding.Create(False)` for BOM-free UTF-8 output in TStreamWriter
- Pre-compiled DCUs in DelphiAST source are x86 only; must use `-B` flag for x64 builds
- `ntCall` = method calls WITH parentheses (e.g., `Exit`, `Exception.Create`)
- `ntDot` = parameterless method/property calls (e.g., `FAnimals[I].GetName`)

## Testing

- `tests/test-project/` - Fixture Delphi files
- `tests/MCP.TestServer.pas` - Server process management
- `tests/MCP.TestHelper.pas` - Test helper utilities
- `tests/Tests.*.pas` - Test fixtures for each MCP tool

## Key Files

- `AST.Query.pas` - AST query operations including call graph extraction
- `MCP.Tools.pas` - MCP tool implementations
- `MCP.Server.pas` - JSON-RPC server implementation
