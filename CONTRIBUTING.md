# Contributing

Thanks for your interest in index-store-mcp.

## Before you start

For a new tool or a change in how an existing tool behaves, please open an issue first so we can agree on the approach. Bug fixes and small improvements can go straight to a pull request.

## Setup

You need Xcode 16 or later. The tests use this package's own Xcode index as a fixture, so build it once in Xcode (or with `xcodebuild`) before running them:

```sh
xcodebuild build -scheme IndexStoreMCP -destination 'platform=macOS' -quiet
swift test
```

See [TESTING.md](TESTING.md) for how the tests and compatibility checks work.

## Things to keep in mind

- **stdout belongs to JSON-RPC.** In server mode, anything else written to stdout (a stray `print`, for example) breaks the MCP connection. Log to stderr if you need to.
- **Tool descriptions are read by agents.** The descriptions in `Server.swift` are how agents decide which tool to call, so changes should keep saying when to prefer the index over grep.
- **Bumping the indexstore-db pin** can raise the minimum Xcode. Run `scripts/check-libindexstore.sh` after changing it.

## Pull requests

- Tests pass (`swift test`), and new behaviour comes with a test.
- User-visible changes get an entry in [CHANGELOG.md](CHANGELOG.md).
- Keep commits focused; each one should explain why the change is needed.

Releases are tagged by the maintainer; the steps are in `.github/workflows/release.yml`.
