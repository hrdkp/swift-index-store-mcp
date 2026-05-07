import MCP
import IndexStoreDB
import Foundation

func handleSymbolAtPosition(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let file = args["file"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: file", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let line = args["line"]?.intValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: line (must be an integer)", annotations: nil, _meta: nil)], isError: true)
    }
    
    let all = database.symbolOccurrences(inFilePath: file)
    let atLine = all.filter { $0.location.line == line }
    
    if atLine.isEmpty {
        return CallTool.Result(content: [.text(text: "[]", annotations: nil, _meta: nil)], isError: false)
    }
    
    let items: [[String: String]] = atLine.map { occurrence in
        [
            "usr":  occurrence.symbol.usr,
            "name": occurrence.symbol.name,
            "kind": String(describing: occurrence.symbol.kind)
        ]
    }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    let text = String(data: data, encoding: .utf8) ?? "Found \(items.count) occurrences"
    
    return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
}
