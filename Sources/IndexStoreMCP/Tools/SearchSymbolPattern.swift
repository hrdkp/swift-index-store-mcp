import MCP
@preconcurrency import IndexStoreDB
import Foundation

func handleSearchSymbolPattern(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let pattern = args["pattern"]?.stringValue else {
        return .failure("Missing required argument: pattern")
    }
    
    let anchorStart   = args["anchorStart"]?.boolValue   ?? false
    let anchorEnd     = args["anchorEnd"]?.boolValue     ?? false
    let subsequence   = args["subsequence"]?.boolValue   ?? true
    let ignoreCase    = args["ignoreCase"]?.boolValue    ?? true
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    let all = database.canonicalOccurrences(
        containing: pattern,
        anchorStart: anchorStart,
        anchorEnd: anchorEnd,
        subsequence: subsequence,
        ignoreCase: ignoreCase
    )
    let nonSystem = all.filter { includeSystem || !$0.location.isSystem }
    let results = nonSystem.filter { includeStale || !$0.isStale(in: database) }
    
    let items: [[String: String]] = results.map { $0.toCanonicalDict() }
    let output = try formatOccurrenceJSON(items, systemCount: all.count - nonSystem.count, staleCount: nonSystem.count - results.count)
    return .success(output)
}
