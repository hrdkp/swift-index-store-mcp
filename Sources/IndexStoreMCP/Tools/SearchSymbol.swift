import MCP
import IndexStoreDB
import Foundation

func handleSearchSymbol(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    .init(
        content: [.text(text: "searchSymbol: not yet implemented", annotations: nil, _meta: nil)],
        isError: true
    )
}
