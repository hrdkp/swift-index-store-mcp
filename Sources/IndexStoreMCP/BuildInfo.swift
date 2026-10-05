/// Single source of truth for identity strings. `--version`, the MCP `Server`
/// handshake, and (later) release tooling must all read from here.
enum BuildInfo {
    static let name = "index-store-mcp"
    static let version = "0.1.1"
    /// Oldest Xcode whose libIndexStore exports every function the pinned
    /// indexstore-db requires. CI checks this against ci/libindexstore-floor.symbols.
    static let minimumXcode = "16.0"
}
