# DelphiAST MCP Server

## Building

Use the batch files in the project root:

Build MCP server:
```bash
"c:/Users/jespe/Documents/Embarcadero/Studio/Projects/DelphiAST_MCP/build.bat"
```

Build test suite:
```bash
"c:/Users/jespe/Documents/Embarcadero/Studio/Projects/DelphiAST_MCP/build-tests.bat"
```

Run the tests:
```bash
"c:/Users/jespe/Documents/Embarcadero/Studio/Projects/DelphiAST_MCP/run-tests.bat"
```

## Architecture

**7 units:**

| Unit | Responsibility |
|---|---|
| `DelphiAST_MCP.dpr` | Entry point: CLI arg parsing, wires parser → tools → server |
| `AST.Parser.pas` | `TASTParser` — roots, parse orchestration, in-memory + disk AST cache, background parse thread |
| `AST.Query.pas` | AST query operations: type detail, call graph extraction, coupling analysis (`TCouplingKind`) |
| `AST.Serialize.pas` | `TFullASTSerializer` — binary AST persistence (`DAST_MCP_V01` format, string-table compressed) |
| `AST.Watcher.pas` | `TDirectoryWatcher` — `ReadDirectoryChangesW` subtree watching with 500 ms debounce, drives cache invalidation |
| `MCP.Tools.pas` | Tool schemas and implementations |
| `MCP.Server.pas` | JSON-RPC server |

**Transport:** JSON-RPC 2.0 over **HTTP** — `POST /mcp` on an Indy `TIdHTTPServer`,
default port 3000. Protocol version `2024-11-05`. This is **not** a stdio server;
any other method or path returns 404 (`MCP.Server.pas:284`).

**Caching:** two tiers.
- In-memory: `TDictionary<string, TCachedTree>` (path → `TSyntaxNode` + mtime),
  guarded by a `TLightweightMREW`.
- On disk: `%TEMP%\DelphiAST_MCP_<12-char MD5 of the joined roots>\<md5>.dast`,
  written via `AST.Serialize` and reloaded on startup (`InitCacheDir`,
  `LoadPersistedCache` in `AST.Parser.pas:243-260, 346`).

## 19 MCP tools

Registered in `MCP.Tools.pas:115-287`, dispatched in `CallTool`.

**Discovery** — `list_files`, `search_symbols`, `symbol_at_position`

**Structure** — `parse_unit`, `get_type_detail`, `get_syntax_tree`, `get_source`,
`get_method_body`

**Relationships** — `find_references` (declarations), `find_usages` (all usage
sites), `get_uses_graph`, `get_call_graph` (callers/callees, recursive with cycle
detection), `resolve_inheritance` (upward), `find_descendants` (downward)

**Analysis** — `analyze_coupling`, `find_weak_couplings`

**Lifecycle** — `set_project`, `get_status`, `is_ready`

Every tool except the three lifecycle tools fails with
`"No project configured. Call set_project first."` when no roots are set
(`MCP.Tools.pas:293`).

`get_source` returns real source text; `get_method_body` returns simplified
statement-level AST. `find_references` finds declarations only; `find_usages`
finds everywhere an identifier is used.

## Running the server

```
DelphiAST_MCP.exe [<project-root>] [--path <dir>]... [--port <n>]
```

- The first non-flag argument is the project root. `--path` adds extra roots and
  is repeatable. All roots are searched as one merged namespace — `ResolveFilePath`
  and `BuildFileIndex` iterate `FRoots` in order and take the first hit.
- The root may be omitted entirely and configured later via `set_project`.
- Startup kicks off a **background** parse. Poll `is_ready` (or `get_status`, which
  reports `state` plus `total_files`/`cached_files`/`parsed_files`/`failed_files`)
  before issuing queries.

### `.delphi-ast.json`

`set_project` looks for `.delphi-ast.json` in the project root
(`MCP.Tools.pas:1397-1457`):

```json
{
  "libraryPaths": ["c:/Users/Public/DelphiLibs/DelphiAST"],
  "excludePaths": ["Generated"],
  "excludeFiles": ["*.generated.pas", "Dog.pas"]
}
```

- `libraryPaths` — extra roots; absolute, or relative to the project root.
- `excludePaths` — directory names skipped during subdirectory expansion.
- `excludeFiles` — filename glob patterns, matched case-insensitively.

`set_project` requires at least one `.dpr` in the root, and **recursively expands
every root to include its subdirectories** (`ExpandWithSubdirs`). The CLI `--path`
flag does not do this expansion — it adds the one directory given. (The file
watcher does watch subtrees in both cases.)

## Concurrency model

**One process serves exactly one source tree.**

- `DelphiAST_MCP.dpr:86-90` creates a single `TASTParser`, one `TMCPTools`, one
  `TMCPServer`. All roots, caches, and the file index live on that one parser.
- The HTTP server has **no session concept** — no `Mcp-Session-Id`, no
  per-connection state; `FInitialized` is a single server-wide flag. Multiple
  clients can POST concurrently, but they all share the same parser.
- `set_project` is therefore **global**: a second client calling it swaps the
  source tree out from under the first. `TASTParser.Reconfigure`
  (`AST.Parser.pas:433`) stops the watcher, frees every cached tree, replaces
  `FRoots`, resets `FHasParsed`, and restarts the background parse.

To serve several source trees, **run one process per tree on its own `--port`**.
Disk cache directories are keyed by a hash of the roots, so instances do not
collide.

## DelphiAST Library Notes

- Field/variable/parameter names stored as `TValuedSyntaxNode` children with `ntName` type (use `.Value`, not `.GetAttribute(anName)`)
- Property read/write accessors stored as `ntIdentifier` children of `ntRead`/`ntWrite` nodes
- Use `TUTF8Encoding.Create(False)` for BOM-free UTF-8 output in TStreamWriter
- Pre-compiled DCUs in DelphiAST source are x86 only; must use `-B` flag for x64 builds
- `ntCall` = method calls WITH parentheses (e.g., `Exit`, `Exception.Create`)
- `ntDot` = parameterless method/property calls (e.g., `FAnimals[I].GetName`)

## Testing

Two test families, both driven by `tests/DelphiAST_MCP_Tests.dpr`:

- `Tests.<Tool>.pas` — end-to-end over HTTP, via `MCP.TestServer.pas` (starts the
  server process once for the whole run) and `MCP.TestHelper.pas`.
- `Tests.DirectTools.<Tool>.pas` — in-process, calling `TMCPTools` directly.

Fixtures live in `tests/test-project/`: `Animals.pas`, `Dog.pas`, `Cat.pas`,
`AnimalRegistry.pas`, `Shapes.pas`, `CouplingDemo.pas`, `ProceduralUnit.pas`,
`TestForwardDecl.pas`, `TestProject.dpr`, a `Generated/` subdirectory (for
`excludePaths` tests), and `.delphi-ast.json`. `tests/test-lib/` backs the
`libraryPaths` tests.

## Key Files

- `AST.Parser.pas` - Roots, caching, background parsing, `Reconfigure`
- `AST.Query.pas` - AST query operations including call graph and coupling analysis
- `MCP.Tools.pas` - MCP tool schemas and implementations
- `MCP.Server.pas` - HTTP JSON-RPC server implementation
