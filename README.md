# index-store-mcp

[![Release](https://img.shields.io/github/v/release/hrdkp/swift-index-store-mcp)](https://github.com/hrdkp/swift-index-store-mcp/releases/latest)
[![Test](https://github.com/hrdkp/swift-index-store-mcp/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/hrdkp/swift-index-store-mcp/actions/workflows/test.yml)
[![License](https://img.shields.io/github/license/hrdkp/swift-index-store-mcp)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Xcode%2016%2B-blue)

An MCP server that gives coding agents semantic code navigation for Xcode projects. Instead of relying on `grep` and file reading, agents can look up symbols by name, find definitions and references by USR, trace protocol conformances and overrides, and get structural outlines of files — the same navigation that Xcode provides via Cmd+Click and Find Usages.

Built on Apple's [IndexStoreDB](https://github.com/swiftlang/indexstore-db) library, which reads the index data that Xcode generates during builds.

## When is this useful?

- **Large codebases** where `grep` returns too much noise. Symbol lookup by USR is exact — no false matches from comments, strings, or similarly named symbols.
- **Refactoring** — find all protocol conformances, method overrides, and extensions before changing a type or interface. `relatedOccurrences` answers "what will break?" in one call.
- **Navigating unfamiliar code** — agents can trace call graphs and jump between definitions and references the same way a developer uses Cmd+Click in Xcode, instead of guessing at file structure.
- **Reducing context window usage** — `symbolsInFile` returns a structural outline (names, kinds, line numbers) without reading the entire source file. For large files this keeps the agent's context focused.
- **Cross-dependency navigation** — the index includes symbols from your project's Swift package dependencies, not just your own source files.

For small projects, `grep` and file reading are usually fast enough. This MCP pays off as project size and complexity grow.

## Requirements

- **Apple silicon Mac**
- **Xcode 16 or later**, selected with `xcode-select` or `DEVELOPER_DIR`. The server loads `libIndexStore.dylib` from the selected Xcode at runtime. Xcode 16 needs macOS 14.5 or later, so that is the effective macOS floor.
- The target project must have been **built in Xcode** at least once, so its index store exists in DerivedData.

## Getting started

### 1. Install

```sh
brew install hrdkp/tap/index-store-mcp
```

<details>
<summary><strong>Build from source</strong></summary>

```sh
git clone https://github.com/hrdkp/swift-index-store-mcp.git
cd swift-index-store-mcp
swift build -c release
swift build -c release --show-bin-path   # prints the directory containing index-store-mcp
```

Use the full path to the built binary in place of `/opt/homebrew/bin/index-store-mcp` below.

</details>

### 2. Add the server to your MCP client

Use the absolute path: GUI apps such as Claude Desktop don't see your shell's `PATH`, so a bare `index-store-mcp` may not be found.

<details>
<summary><strong>Claude Code</strong></summary>

```sh
claude mcp add index-store-mcp /opt/homebrew/bin/index-store-mcp
```

</details>

<details>
<summary><strong>Claude Desktop / Cursor / other MCP clients</strong></summary>

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "index-store-mcp": {
      "command": "/opt/homebrew/bin/index-store-mcp"
    }
  }
}
```

To use a different Xcode than the one `xcode-select` points to, add `"env": { "DEVELOPER_DIR": "/Applications/Xcode-16.0.app/Contents/Developer" }`.

</details>

### 3. Tell your agent to use it

Adding the server makes the tools *available*, but agents often default to `grep` unless told otherwise. From your project's root, append the bundled instructions to its `CLAUDE.md` (or `AGENTS.md`, or your agent's equivalent). Run this once; running it again adds a second copy:

```sh
index-store-mcp --print-agent-instructions >> CLAUDE.md
```

**Try it:** build your project in Xcode once, then ask your agent something like "Find every type that conforms to `MyProtocol`." It should call `loadIndex` first, then answer from the index instead of searching with `grep`.

## How it works

When Xcode builds a project, the compiler writes symbol index data to `DerivedData/<project>/Index.noindex/DataStore`. index-store-mcp reads this data through IndexStoreDB, using the `libIndexStore.dylib` from your selected Xcode, and exposes it over the [Model Context Protocol](https://modelcontextprotocol.io) via stdio.

The server finds DerivedData automatically by checking:
1. The custom DerivedData location from Xcode preferences
2. A `DerivedData` folder next to the workspace (relative mode)
3. The default `~/Library/Developer/Xcode/DerivedData`

It keeps its own lookup database in `~/Library/Caches/index-store-mcp`.

## Troubleshooting

- **"No DerivedData found"** — build the project in Xcode (Cmd+B) at least once, then call `loadIndex` again.
- **"libIndexStore … is not compatible"** — the selected Xcode is older than Xcode 16. Run `xcode-select -p` to see which one is selected, then switch with `sudo xcode-select -s /Applications/Xcode.app` or set `DEVELOPER_DIR` in your MCP client config.
- **Results are missing or out of date** — rebuild in Xcode, then call `refreshIndex`. If you build with a newer Xcode than the selected one, select the newer Xcode: the `loadIndex` result shows which `libIndexStore.dylib` is in use.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute, [TESTING.md](TESTING.md) for running the tests, and [CHANGELOG.md](CHANGELOG.md) for release history. To report a security issue, see [SECURITY.md](SECURITY.md).

## License

index-store-mcp is released under the MIT License. See [LICENSE](LICENSE) for details.
