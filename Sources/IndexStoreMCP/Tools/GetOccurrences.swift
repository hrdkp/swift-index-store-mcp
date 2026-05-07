import MCP
import IndexStoreDB
import Foundation

func handleGetOccurrences(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    .init(
        content: [.text(text: "getOccurrences: not yet implemented", annotations: nil, _meta: nil)],
        isError: true
    )
}
