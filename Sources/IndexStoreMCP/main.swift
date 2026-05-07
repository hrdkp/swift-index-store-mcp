import MCP
import Foundation

let indexStore = IndexStore()
let server = Server(
    name: "IndexStoreMCP",
    version: "1.0.0",
    capabilities: Server.Capabilities(tools: .init())
)
await registerTools(on: server, indexStore: indexStore)
let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
