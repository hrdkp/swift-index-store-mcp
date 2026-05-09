import Foundation
import MCP
@preconcurrency import IndexStoreDB

func handleRefreshIndex(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let db = await indexStore.database,
          let workspacePath = await indexStore.loadedWorkspacePath else {
        return CallTool.Result(
            content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    // pollForUnitChangesAndWait() is a blocking filesystem scan that can take
    // several seconds on large projects. Run it on a DispatchQueue thread so it
    // does not tie up the Swift concurrency thread pool.
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            db.pollForUnitChangesAndWait()
            continuation.resume()
        }
    }
    
    return CallTool.Result(
        content: [.text(text: "Index refreshed for workspace: \(workspacePath)", annotations: nil, _meta: nil)]
    )
}
