# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.1]

### Fixed
- `relatedOccurrences` now returns what its description promises for types and
  protocols. For a protocol it lists every conforming type, including indirect
  conformers through sub-protocols (marked with `via`); for a class, every
  subclass; and for a type or protocol, its extensions. Previously it returned
  member usages instead. Methods and properties are unchanged.
- Results no longer include occurrences from index data left by earlier builds.
  Xcode keeps old index units alongside current ones, so the same file could
  return outdated line numbers that looked current. `getOccurrences`,
  `relatedOccurrences`, `searchSymbol`, and `searchSymbolPattern` now judge
  each result by the build that produced it. `symbolsInFile` and
  `symbolAtPosition` keep the previous file-level check for now.

## [0.1.0] - 2026-10-05

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

[0.1.1]: https://github.com/hrdkp/swift-index-store-mcp/releases/tag/v0.1.1
[0.1.0]: https://github.com/hrdkp/swift-index-store-mcp/releases/tag/v0.1.0
