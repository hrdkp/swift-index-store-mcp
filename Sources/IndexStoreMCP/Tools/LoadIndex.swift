import MCP
import IndexStoreDB
import Foundation

func handleLoadIndex(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    .init(
        content: [.text(text: "loadIndex: not yet implemented", annotations: nil, _meta: nil)],
        isError: true
    )
}
