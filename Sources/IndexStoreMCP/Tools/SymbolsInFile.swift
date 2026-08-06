import MCP
@preconcurrency import IndexStoreDB
import Foundation

func handleSymbolsInFile(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let file = args["file"]?.stringValue else {
        return .failure("Missing required argument: file")
    }
    
    let roleStrings = args["roles"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let (roles, unknownRoles) = symbolRole(from: roleStrings, defaultRole: .definition)
    if !unknownRoles.isEmpty {
        return .failure("Unknown role(s): \(unknownRoles.joined(separator: ", ")). Valid roles: \(validRoleNames)")
    }
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    let all = database.symbolOccurrences(inFilePath: file)
    let roleFiltered = all.filter { !$0.roles.intersection(roles).isEmpty }
    let nonSystem = roleFiltered.filter { includeSystem || !$0.location.isSystem }
    let results = nonSystem.filter { includeStale || !$0.isStale(in: database) }
    if results.isEmpty && all.isEmpty {
        return .success("No symbols found in this file. The file may not be indexed — try rebuilding the project and calling refreshIndex.")
    }
    
    let sorted = results.sorted { $0.location.line < $1.location.line }
    
    let items: [[String: Any]] = sorted.map { occurrence in
        var dict: [String: Any] = [
            "name":   occurrence.symbol.name,
            "usr":    occurrence.symbol.usr,
            "kind":   String(describing: occurrence.symbol.kind),
            "line":   occurrence.location.line,
            "column": occurrence.location.utf8Column,
            "role":   String(describing: occurrence.roles),
        ]
        if occurrence.symbol.subKind != .none {
            dict["subKind"] = String(describing: occurrence.symbol.subKind)
        }
        return dict
    }
    
    let output = try formatOccurrenceJSON(items, systemCount: roleFiltered.count - nonSystem.count, staleCount: nonSystem.count - results.count)
    return .success(output)
}
