import MCP
@preconcurrency import IndexStoreDB
import Foundation

func handleSearchSymbol(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let name = args["name"]?.stringValue else {
        return .failure("Missing required argument: name")
    }
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    var all = database.canonicalOccurrences(ofName: name).uniqued()
    var nonSystem = all.filter { includeSystem || !$0.location.isSystem }
    var results = nonSystem.filter { includeStale || !$0.isStale(in: database) }
    
    // Exact match failed (or was entirely stale) — try prefix match to handle
    // bare method names (e.g. "reserveLoading" → "reserveLoading(workspacePath:)").
    if results.isEmpty {
        all = database.canonicalOccurrences(
            containing: name,
            anchorStart: true,
            anchorEnd: false,
            subsequence: false,
            ignoreCase: false
        ).uniqued()
        nonSystem = all.filter { includeSystem || !$0.location.isSystem }
        results = nonSystem.filter { includeStale || !$0.isStale(in: database) }
        
        if results.isEmpty {
            return .success("No match found for '\(name)'. Try searchSymbolPattern with a partial name.")
        }
    }
    
    let items: [[String: String]] = results.map { $0.toCanonicalDict() }
    let output = try formatOccurrenceJSON(items, systemCount: all.count - nonSystem.count, staleCount: nonSystem.count - results.count)
    return .success(output)
}
