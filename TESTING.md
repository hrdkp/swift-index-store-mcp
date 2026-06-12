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
`xcodebuild build` before `swift test` to generate the index store.

The key steps are:

```sh
xcodebuild build -scheme IndexStoreMCP -destination 'platform=macOS' -quiet
swift test
```

## What the tests cover

| Suite              | Tests | What it verifies                                          |
|--------------------|-------|-----------------------------------------------------------|
| loadIndex          | 5     | Success, idempotency, workspace rejection, path validation|
| searchSymbol       | 3     | Known symbol lookup, unknown symbol message, guard check  |
| symbolAtPosition   | 4     | Exact match, column snapping, empty line, arg validation  |
| symbolsInFile      | 1     | Structural outline of a known file                        |
| getOccurrences     | 3     | Known USR, bogus USR, invalid role rejection              |
| IndexStore actor   | 3     | Reserve/load/end lifecycle, concurrent load blocking      |

## Adding new tests

Tests derive the workspace path from `#filePath` at compile time — no hardcoded paths.
When adding tests that query the index, use symbols defined in this project's own
source files so the assertions are stable.
