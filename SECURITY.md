# Security policy

## Supported versions

Only the latest release receives fixes. While the project is at 0.x, fixes ship in a new release rather than as patches to older ones.

## Reporting a vulnerability

Please don't open a public issue. Report it privately through GitHub instead: go to the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainer can see the report.

Include what you found, how to reproduce it, and the output of `index-store-mcp --version`.

This is a one-person project, so responses are best effort. Expect an acknowledgement within a week, and a fix or a decision once the issue is understood.

## Scope

index-store-mcp runs locally and makes no network connections. It reads Xcode's index store from DerivedData, keeps a cache in `~/Library/Caches/index-store-mcp`, and loads `libIndexStore.dylib` from the selected Xcode.

In scope:
- Tool arguments (such as file or workspace paths) that make the server read, expose, or write data it shouldn't.
- Anything that corrupts the JSON-RPC stream the server writes to stdout.

Out of scope: vulnerabilities in Xcode or `libIndexStore.dylib` (report them to Apple) and in [indexstore-db](https://github.com/swiftlang/indexstore-db) (report them to the Swift project).
