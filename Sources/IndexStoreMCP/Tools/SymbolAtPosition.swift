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
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    
    let atLine = database.symbolOccurrences(inFilePath: file)
        .filter { $0.location.line == line }
        .filter { includeSystem || !$0.location.isSystem }
        .sorted { $0.location.utf8Column < $1.location.utf8Column }
    
    guard !atLine.isEmpty else {
        return .success("No symbols found at \(file):\(line). The file may not be indexed — try rebuilding the project and calling refreshIndex.")
    }
    
    let items: [[String: Any]] = atLine.map { occurrence in
        var dict: [String: Any] = [
            "column": occurrence.location.utf8Column,
            "usr":    occurrence.symbol.usr,
            "name":   occurrence.symbol.name,
            "kind":   String(describing: occurrence.symbol.kind),
        ]
        if occurrence.symbol.subKind != .none {
            dict["subKind"] = String(describing: occurrence.symbol.subKind)
        }
        return dict
    }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    return .success(String(data: data, encoding: .utf8) ?? "[]")
}
