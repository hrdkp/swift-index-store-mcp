# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0]

First release, distributed as a prebuilt Apple silicon binary through Homebrew.

### Added
- MCP server over stdio with eight tools: `loadIndex`, `searchSymbol`,
  `searchSymbolPattern`, `symbolAtPosition`, `getOccurrences`,
  `relatedOccurrences`, `symbolsInFile`, `refreshIndex`.
- `--version`, `--help`, and `--print-agent-instructions` (a snippet for
  `CLAUDE.md` / `AGENTS.md` that tells agents to prefer the index over grep).
- `loadIndex` reports which `libIndexStore.dylib` it loaded, and explains how to
  select a newer Xcode when the selected one is too old.

### Requirements
- Apple silicon Mac with Xcode 16 or later selected (`xcode-select` or
  `DEVELOPER_DIR`).

[0.1.0]: https://github.com/hrdkp/swift-index-store-mcp/releases/tag/v0.1.0
