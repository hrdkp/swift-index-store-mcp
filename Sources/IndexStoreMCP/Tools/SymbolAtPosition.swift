import MCP
@preconcurrency import IndexStoreDB
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
    
    guard let column = args["column"]?.intValue else {
        return .failure("Missing required argument: column (must be an integer, 1-based UTF-8 offset)")
    }
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    let onLine = database.symbolOccurrences(inFilePath: file)
        .filter { $0.location.line == line }
        .filter { includeSystem || !$0.location.isSystem }
        .filter { includeStale || !$0.isStale(in: database) }
    
    // Find the closest symbol at or before the requested column.
    guard let match = onLine
        .filter({ $0.location.utf8Column <= column })
        .max(by: { $0.location.utf8Column < $1.location.utf8Column })
    else {
        return .success("No symbol found at \(file):\(line):\(column). The file may not be indexed, or the only match here is stale (source edited since last indexed) — try rebuilding the project and calling refreshIndex, or pass includeStale: true.")
    }
    
    var dict: [String: Any] = [
        "line":   match.location.line,
        "column": match.location.utf8Column,
        "usr":    match.symbol.usr,
        "name":   match.symbol.name,
        "kind":   String(describing: match.symbol.kind),
        "role":   String(describing: match.roles),
    ]
    if match.symbol.subKind != .none {
        dict["subKind"] = String(describing: match.symbol.subKind)
    }
    
    let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    return .success(String(data: data, encoding: .utf8) ?? "{}")
}
