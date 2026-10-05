# Testing

## How the tests work

IndexStoreMCP tests are **integration tests that use the project's own Xcode index as
a fixture**. The test suite calls the same tool handlers that the MCP server exposes,
pointed at the IndexStoreMCP source code itself. This means the tests exercise the
full path: IndexStoreDB queries, system symbol filtering, result formatting, and error
handling.

Because the tests query a real index, they require an Xcode-generated index store in
DerivedData before they can run.

## Running tests locally

1. **Open the project in Xcode** (File > Open > select the `IndexStoreMCP` directory).
Xcode will resolve packages and build the index automatically.

2. **Build once** in Xcode (`Cmd+B`) to ensure the index store is fully populated.

3. **Run the tests:**

```sh
swift test
```

Alternatively, run tests directly in Xcode with `Cmd+U`.

If you only use `swift build` from the command line (without ever opening Xcode), the
index store won't exist and the integration tests will fail with a "No DerivedData
found" error.

## Running tests in CI

The GitHub Actions workflow (`.github/workflows/test.yml`) runs on every push to
`main` and on pull requests. It uses a macOS runner with Xcode pre-installed and runs
`xcodebuild build` before `swift test` to generate the index store, then checks
libIndexStore compatibility, builds the release binary, and smoke-tests it.

The key steps are:

```sh
xcodebuild build -scheme IndexStoreMCP -destination 'platform=macOS' -quiet
swift test
scripts/check-libindexstore.sh
scripts/smoke-test.sh "$(swift build -c release --show-bin-path)/index-store-mcp"
```

## What the tests cover

| Suite                         | Tests | What it verifies                                                        |
|-------------------------------|-------|-------------------------------------------------------------------------|
| loadIndex                     | 6     | Success, reader reporting, no `.unknown` symbol kinds, idempotency, workspace and path validation |
| searchSymbol                  | 4     | Known symbol lookup, unknown symbol message, prefix fallback, guard check |
| symbolAtPosition              | 4     | Exact match, column snapping, empty line, arg validation                |
| symbolsInFile                 | 1     | Structural outline of a known file                                      |
| getOccurrences                | 3     | Known USR, bogus USR, invalid role rejection                            |
| IndexStore actor              | 3     | Reserve/load/end lifecycle, concurrent load blocking                    |
| staleness checks              | 6     | Orphaned and out-of-date detection for deleted and edited files         |
| formatOccurrenceJSON stale note | 3   | Notes and counts for excluded stale and system results                  |

`noUnknownSymbolKinds` is a ceiling check: when CI's Xcode is newer than the pinned
indexstore-db understands, symbols come back as `.unknown` and the test fails.

## libIndexStore compatibility checks

The binary loads `libIndexStore.dylib` from the user's selected Xcode at runtime, so
compatibility depends on the pinned indexstore-db revision, not on the macOS version
CI runs on. `scripts/check-libindexstore.sh` checks two things:

- **Floor (fails):** every function the pinned indexstore-db marks required is
  exported by the oldest supported Xcode, recorded in `ci/libindexstore-floor.symbols`.
- **Ceiling (warns):** the selected Xcode exports no functions the pin doesn't load.
  If it does, upstream has moved on and the pin may be getting stale.

It runs in `test.yml` and in the release workflow. `libindexstore-compat.yml` runs it
weekly against every Xcode on the runner image and against upstream indexstore-db
`main`, failing on either kind of change.

When bumping the indexstore-db pin, run the script locally. When raising the minimum
Xcode, update `BuildInfo.minimumXcode` and recapture the snapshot from the oldest point
release of that Xcode:

```sh
scripts/capture-libindexstore-floor.sh /Applications/Xcode-16.0.app
```

## Adding new tests

Tests derive the workspace path from `#filePath` at compile time — no hardcoded paths.
When adding tests that query the index, use symbols defined in this project's own
source files so the assertions are stable.
