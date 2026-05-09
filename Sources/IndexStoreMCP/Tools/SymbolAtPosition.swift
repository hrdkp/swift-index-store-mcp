import MCP
import IndexStoreDB
import Foundation

func handleSymbolAtPosition(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let file = args["file"]?.stringValue else {
        return .failure("Missing required argument: file")
    }
    
    guard let line = args["line"]?.intValue else {
        return .failure("Missing required argument: line (must be an integer)")
    }
    
    let all = database.symbolOccurrences(inFilePath: file)
    let atLine = all.filter { $0.location.line == line }
    
    if atLine.isEmpty {
        return .success("[]")
    }
    
    let items: [[String: String]] = atLine.map { occurrence in
        var dict: [String: String] = [
            "usr":  occurrence.symbol.usr,
            "name": occurrence.symbol.name,
            "kind": String(describing: occurrence.symbol.kind),
        ]
        if occurrence.symbol.subKind != .none {
            dict["subKind"] = String(describing: occurrence.symbol.subKind)
        }
        return dict
    }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    let text = String(data: data, encoding: .utf8) ?? "Found \(items.count) occurrences"
    
    return .success(text)
}
