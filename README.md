# IndexStoreMCP

An MCP server that gives AI agents semantic code navigation for Xcode projects. Instead of relying on `grep` and file reading, agents can look up symbols by name, find definitions and references by USR, trace protocol conformances and overrides, and get structural outlines of files — the same navigation that Xcode provides via Cmd+Click and Find Usages.

Built on Apple's [IndexStoreDB](https://github.com/swiftlang/indexstore-db) library, which reads the index data that Xcode generates during builds.

## When is this useful?

- **Large codebases** where `grep` returns too much noise. Symbol lookup by USR is exact — no false matches from comments, strings, or similarly named symbols.
- **Refactoring** — find all protocol conformances, method overrides, and extensions before changing a type or interface. `relatedOccurrences` answers "what will break?" in one call.
- **Navigating unfamiliar code** — agents can trace call graphs and jump between definitions and references the same way a developer uses Cmd+Click in Xcode, instead of guessing at file structure.
- **Reducing context window usage** — `symbolsInFile` returns a structural outline (names, kinds, line numbers) without reading the entire source file. For large files this keeps the agent's context focused.
- **Cross-dependency navigation** — the index includes symbols from your project's Swift package dependencies, not just your own source files.

For small projects, `grep` and file reading are usually fast enough. This MCP pays off as project size and complexity grow.

## Prerequisites

- **macOS 14+**
- **Xcode** installed (provides `libIndexStore.dylib`)
- The target project must have been **built in Xcode** at least once so the index store exists in DerivedData

## Setup

### Build

```sh
git clone https://github.com/hpatel-lincoln/swift-index-store-mcp.git
cd swift-index-store-mcp
swift build -c release
```

The binary is at `.build/release/index-store-mcp` inside the cloned directory.

### Configure your MCP client

<details>
<summary><strong>Claude Code</strong></summary>

```sh
claude mcp add index-store-mcp /path/to/swift-index-store-mcp/.build/release/index-store-mcp
```

</details>

<details>
<summary><strong>Claude Desktop / Cursor / other MCP clients</strong></summary>

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "index-store-mcp": {
      "command": "/path/to/swift-index-store-mcp/.build/release/index-store-mcp"
    }
  }
}
```

</details>

### Configuring your agent

Adding the MCP server makes the tools *available*, but agents will often default to `grep` unless instructed otherwise. Add the following to your project's `CLAUDE.md` (or equivalent agent instructions file) to encourage the agent to use the index:

```markdown
## Xcode Navigation (index-store-mcp)

This project has the index-store-mcp server configured. Use it for code navigation
instead of grep when working with Swift/Objective-C source files.

### When to use
- Finding where a symbol is defined, referenced, or called
- Tracing protocol conformances, method overrides, or extensions
- Getting a structural outline of a file before reading it
- Disambiguating symbols with common names (e.g., init, configure, handle)
- Identifying a symbol's type or kind (class, protocol, enum, method, property)
- Navigating into symbols defined in package dependencies

### Workflow
1. Call `loadIndex` with the workspace/project path once at the start of a session
2. Use `searchSymbol` (exact name, preferred) or `searchSymbolPattern` (fuzzy/partial,
   use longer patterns to reduce noise) to find USRs
3. Use `getOccurrences` or `relatedOccurrences` with a USR to find all usage sites
4. Use `symbolAtPosition` when you're reading a file and need the USR at a specific position
5. Use `symbolsInFile` to get a file's structure without reading the full source
6. Call `refreshIndex` after a build to pick up changes
```

## Tools (invoked by the agent)

### loadIndex

Must be called first. Loads the Xcode index for a project.

```
workspacePath: "/path/to/MyApp.xcworkspace"
```

Accepts `.xcworkspace`, `.xcodeproj`, or a bare directory (for Swift packages opened in Xcode).

### searchSymbol

Looks up a symbol by its exact name as it appears in source code. Returns one or more USRs (Unified Symbol Resolutions) that uniquely identify the symbol.

```
name: "viewDidLoad"
```

### searchSymbolPattern

Fuzzy search when you only know a partial name. Supports subsequence matching — `mvc` finds `MyViewController`, `vdl` finds `viewDidLoad`.

```
pattern: "mvc"
```

### symbolAtPosition

Returns the symbol at a specific file location. More precise than `searchSymbol` when the name is ambiguous (e.g., `init`).

```
file: "/path/to/MyFile.swift", line: 42, column: 10
```

### getOccurrences

Given a USR, returns every location where that symbol is defined, referenced, or called. Supports role filtering (`definition`, `reference`, `call`, etc.).

```
usr: "s:13MyApp0A14ViewControllerC"
```

### relatedOccurrences

Finds structural relationships: protocol conformances, method overrides, type extensions. Essential before refactoring a protocol or base class.

```
usr: "s:13MyApp0A8ProtocolP"
```

### symbolsInFile

Returns a structural outline of all symbols defined in a file — names, kinds, USRs, and line numbers.

```
file: "/path/to/MyFile.swift"
```

### refreshIndex

Polls for index changes after a build. Call this when query results may be stale.

## Typical agent workflow

```
loadIndex(workspacePath: "/path/to/MyApp.xcworkspace")
  → "Index loaded"

searchSymbol(name: "AppDelegate")
  → [{ usr: "s:5MyApp0A8DelegateC", kind: "class", location: "AppDelegate.swift:3" }]

getOccurrences(usr: "s:5MyApp0A8DelegateC", roles: ["reference"])
  → [{ file: "main.swift", line: 12, role: "reference" }, ...]

symbolsInFile(file: "/path/to/AppDelegate.swift")
  → [{ name: "AppDelegate", kind: "class", line: 3 },
     { name: "application(_:didFinishLaunchingWithOptions:)", kind: "instanceMethod", line: 5 }, ...]
```

## How it works

When Xcode builds a project, the compiler writes symbol index data to `DerivedData/Index.noindex/DataStore`. IndexStoreMCP reads this data through IndexStoreDB and exposes it over the [Model Context Protocol](https://modelcontextprotocol.io) via stdio transport.

The server discovers DerivedData automatically by checking:
1. Custom DerivedData location from Xcode preferences
2. A `DerivedData` folder next to the workspace (relative mode)
3. The default `~/Library/Developer/Xcode/DerivedData`

System framework symbols (UIKit, Foundation, etc.) are filtered out by default. Pass `includeSystem: true` to any tool to include them.

## Testing

See [TESTING.md](TESTING.md).

## License

IndexStoreMCP is released under the MIT License. See [LICENSE](LICENSE) for details.
