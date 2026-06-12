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
    
    var all = database.canonicalOccurrences(ofName: name)
    var results = all.filter { includeSystem || !$0.location.isSystem }
    
    // Exact match failed — try prefix match to handle bare method names
    // (e.g. "reserveLoading" → "reserveLoading(workspacePath:)").
    if results.isEmpty {
        all = database.canonicalOccurrences(
            containing: name,
            anchorStart: true,
            anchorEnd: false,
            subsequence: false,
            ignoreCase: false
        )
        results = all.filter { includeSystem || !$0.location.isSystem }
        
        if results.isEmpty {
            return .success("No match found for '\(name)'. Try searchSymbolPattern with a partial name.")
        }
    }
    
    let items: [[String: String]] = results.map { $0.toCanonicalDict() }
    let output = try formatOccurrenceJSON(items, systemCount: all.count - results.count)
    return .success(output)
}
