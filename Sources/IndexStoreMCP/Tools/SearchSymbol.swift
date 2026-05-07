import MCP
import IndexStoreDB
import Foundation

func handleSearchSymbol(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let name = args["name"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: name", annotations: nil, _meta: nil)], isError: true)
    }
    
    let occurrences = database.canonicalOccurrences(ofName: name)
    
    if occurrences.isEmpty {
        return CallTool.Result(content: [.text(text: "[]", annotations: nil, _meta: nil)], isError: false)
    }
    
    let items: [[String: String]] = occurrences.map { occurrence in
        [
            "usr":      occurrence.symbol.usr,
            "name":     occurrence.symbol.name,
            "kind":     String(describing: occurrence.symbol.kind),
            "location": occurrence.location.path + ":" + String(occurrence.location.line)
        ]
    }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    let text = String(data: data, encoding: .utf8) ?? "Found \(items.count) occurrences"
    
    return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
}
