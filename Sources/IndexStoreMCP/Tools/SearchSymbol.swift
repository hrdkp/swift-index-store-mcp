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
    
    let occurrences = database.canonicalOccurrences(ofName: name)
    
    if occurrences.isEmpty {
        return .success("No exact match found for '\(name)'. If you expected a result, try searchSymbolPattern with a partial name.")
    }
    
    let items: [[String: String]] = occurrences.map { $0.toCanonicalDict() }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    let text = String(data: data, encoding: .utf8) ?? "Found \(items.count) occurrences"
    
    return .success(text)
}
