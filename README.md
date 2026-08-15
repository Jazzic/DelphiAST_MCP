# DelphiAST_MCP

An MCP server that exposes a Delphi codebase as a queryable Abstract Syntax Tree.

It parses every `.pas`/`.dpr` under one or more source roots using
[DelphiAST](https://github.com/RomanYankovsky/DelphiAST), keeps the trees in
memory (backed by a binary on-disk cache), watches the directories for changes,
and serves 19 tools over JSON-RPC 2.0 — so an MCP client can ask structural
questions about the code instead of grepping it.

## Requirements

- Delphi 11+ command-line compiler (`dcc64.exe` — the build script points at
  `C:\Program Files (x86)\Embarcadero\Studio\23.0\bin`)
- DelphiAST sources at `C:\Users\Public\DelphiLibs\DelphiAST\Source`
- Windows (the file watcher uses `ReadDirectoryChangesW`)

## Build

```bash
build.bat
```

Produces `bin64\DelphiAST_MCP.exe`. The `-B` (build all) flag is required: the
pre-compiled DCUs shipped with DelphiAST are x86 only.

Tests:

```bash
build-tests.bat
run-tests.bat
```

## Run

```
DelphiAST_MCP.exe [<project-root>] [--path <dir>]... [--port <n>]
```

| Argument | Meaning |
|---|---|
| `<project-root>` | First non-flag argument. Optional — can be set later with the `set_project` tool. |
| `--path <dir>` | Additional source root. Repeatable. All roots are searched as one merged namespace. |
| `--port <n>` | HTTP port. Default `3000`. |

The server listens on `http://localhost:<port>/mcp` and accepts `POST` only.
Parsing runs in the background at startup — poll `is_ready` (or `get_status`)
before querying.

### Client configuration

```json
{
  "mcpServers": {
    "delphi-ast": {
      "type": "http",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

### Project configuration

Drop a `.delphi-ast.json` in the project root; `set_project` reads it:

```json
{
  "libraryPaths": ["c:/Users/Public/DelphiLibs/DelphiAST"],
  "excludePaths": ["Generated"],
  "excludeFiles": ["*.generated.pas"]
}
```

- `libraryPaths` — extra source roots (absolute, or relative to the project root)
- `excludePaths` — directory names skipped when expanding subdirectories
- `excludeFiles` — filename globs to ignore, matched case-insensitively

`set_project` requires at least one `.dpr` in the root and expands every root
recursively to include its subdirectories.

## Tools

**Discovery**
- `list_files` — all `.pas`/`.dpr` under the roots, with optional name filter
- `search_symbols` — substring search across all symbols, relevance-ranked
- `symbol_at_position` — what's at file:line:col, plus enclosing type/method

**Structure**
- `parse_unit` — unit name, uses clauses, types, constants, routines with lines
- `get_type_detail` — fields, methods with signatures, properties, by visibility
- `get_syntax_tree` — raw AST subtree as compact JSON
- `get_source` — real source text for a symbol or line range
- `get_method_body` — method body as simplified statement-level AST

**Relationships**
- `find_references` — declarations matching a name pattern
- `find_usages` — every site an identifier is actually used
- `get_uses_graph` — what a unit uses, and who uses it
- `get_call_graph` — callers or callees, recursive with cycle detection
- `resolve_inheritance` — walk ancestors across units
- `find_descendants` — walk subclasses across units

**Analysis**
- `analyze_coupling` — cross-unit symbol usage by kind (inheritance, field_type,
  param_type, return_type, local_var, qualified_call, typecast, cast)
- `find_weak_couplings` — per unit, the dependencies with the weakest (easiest to
  break) coupling, scored by kind weight

**Lifecycle**
- `set_project` — point the server at a source tree
- `get_status` — parse state and file counts
- `is_ready` — has the background parse finished

## One process per source tree

The server holds a single parser instance and has no MCP session handling, so
`set_project` is global — a second client calling it replaces the source tree for
everyone. To work with several codebases at once, run one process per tree on its
own `--port`. On-disk caches are keyed by a hash of the roots, so instances do not
collide.
