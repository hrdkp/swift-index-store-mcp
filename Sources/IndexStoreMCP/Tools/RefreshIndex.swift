import MCP
import IndexStoreDB

func handleRefreshIndex(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let db = await indexStore.database,
          let workspacePath = await indexStore.loadedWorkspacePath else {
        return CallTool.Result(
            content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    db.pollForUnitChangesAndWait()
    
    return CallTool.Result(
        content: [.text(text: "Index refreshed for workspace: \(workspacePath)", annotations: nil, _meta: nil)]
    )
}
