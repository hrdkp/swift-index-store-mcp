import MCP
import IndexStoreDB
import Foundation

func handleSearchSymbol(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let name = args["name"]?.stringValue else {
        return .failure("Missing required argument: name")
    }
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    
    let all = database.canonicalOccurrences(ofName: name)
    let results = all.filter { includeSystem || !$0.location.isSystem }
    
    if results.isEmpty {
        return .success("No exact match found for '\(name)'. If you expected a result, try searchSymbolPattern with a partial name.")
    }
    
    let items: [[String: String]] = results.map { $0.toCanonicalDict() }
    let output = try formatOccurrenceJSON(items, systemCount: all.count - results.count)
    return .success(output)
}
