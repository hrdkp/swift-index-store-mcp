import MCP
import IndexStoreDB
import Foundation

func handleRelatedOccurrences(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return .failure("No index loaded. Call loadIndex first.")
    }
    
    guard let usr = args["usr"]?.stringValue else {
        return .failure("Missing required argument: usr")
    }
    
    let roleStrings = args["roles"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let (roles, unknownRoles) = symbolRole(from: roleStrings, defaultRole: .all)
    if !unknownRoles.isEmpty {
        return .failure("Unknown role(s): \(unknownRoles.joined(separator: ", ")). Valid roles: \(validRoleNames)")
    }
    
    let includeSystem = args["includeSystem"]?.boolValue ?? false
    
    let all = database.occurrences(relatedToUSR: usr, roles: roles)
    let results = all
        .filter { includeSystem || !$0.location.isSystem }
        .sorted { ($0.location.path, $0.location.line) < ($1.location.path, $1.location.line) }
    
    let dicts: [[String: Any]] = results.map { $0.toDetailedDict() }
    
    let output = try formatOccurrenceJSON(dicts, systemCount: all.count - results.count)
    return .success(output)
}
