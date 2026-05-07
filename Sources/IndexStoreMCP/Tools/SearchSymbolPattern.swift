import MCP
import IndexStoreDB
import Foundation

func handleSearchSymbolPattern(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let pattern = args["pattern"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: pattern", annotations: nil, _meta: nil)], isError: true)
    }
    
    let anchorStart   = args["anchorStart"]?.boolValue   ?? false
    let anchorEnd     = args["anchorEnd"]?.boolValue     ?? false
    let subsequence   = args["subsequence"]?.boolValue   ?? true
    let ignoreCase    = args["ignoreCase"]?.boolValue    ?? true
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    
    let all = database.canonicalOccurrences(
        containing: pattern,
        anchorStart: anchorStart,
        anchorEnd: anchorEnd,
        subsequence: subsequence,
        ignoreCase: ignoreCase
    )
    let results = all.filter { includeSystem || !$0.location.isSystem }
    
    if results.isEmpty {
        var msg = "[]"
        let systemCount = all.count - results.count
        if systemCount > 0 {
            msg += "\n\nNote: \(systemCount) system framework occurrence(s) excluded. Pass includeSystem: true to include them."
        }
        return CallTool.Result(content: [.text(text: msg, annotations: nil, _meta: nil)], isError: false)
    }
    
    let items: [[String: String]] = results.map { occurrence in
        [
            "usr":      occurrence.symbol.usr,
            "name":     occurrence.symbol.name,
            "kind":     String(describing: occurrence.symbol.kind),
            "location": occurrence.location.path + ":" + String(occurrence.location.line),
        ]
    }
    
    var output = (String(data: try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted), encoding: .utf8) ?? "[]")
    let systemCount = all.count - results.count
    if systemCount > 0 {
        output += "\n\nNote: \(systemCount) system framework occurrence(s) excluded. Pass includeSystem: true to include them."
    }
    
    return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)], isError: false)
}
