import ArgumentParser
import MCP

@main
struct Command: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: BuildInfo.name,
        abstract: "MCP server giving coding agents semantic code navigation for Xcode projects.",
        discussion: """
        Run with no arguments to start the server on stdio. It is meant to be
        launched by an MCP client, not used interactively.

        Requirements:
          - macOS with Xcode 16 or later selected (provides libIndexStore.dylib).
          - The target project must have been built in Xcode at least once, so an
            index store exists in DerivedData. The server checks the custom location
            from Xcode preferences, a DerivedData folder next to the workspace, and
            ~/Library/Developer/Xcode/DerivedData.

        Client configuration:
          { "mcpServers": { "index-store-mcp": { "command": "index-store-mcp" } } }
        """,
        version: BuildInfo.version
    )

    @Flag(help: "Print a snippet for CLAUDE.md / AGENTS.md that tells agents to prefer this server over grep, then exit.")
    var printAgentInstructions = false

    func run() async throws {
        // Only the flag paths may write to stdout; server mode must never print,
        // since stdout carries the JSON-RPC stream.
        if printAgentInstructions {
            print(AgentInstructions.text)
            return
        }
        let indexStore = IndexStore()
        let server = Server(
            name: BuildInfo.name,
            version: BuildInfo.version,
            capabilities: Server.Capabilities(tools: .init())
        )
        await registerTools(on: server, indexStore: indexStore)
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }
}
