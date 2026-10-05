import MCP
@preconcurrency import IndexStoreDB
import Foundation

func handleGetOccurrences(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
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
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    let all = database.occurrences(ofUSR: usr, roles: roles).uniqued()
    let nonSystem = all.filter { includeSystem || !$0.location.isSystem }
    let results = nonSystem
        .filter { includeStale || !$0.isStale(in: database) }
        .sorted { ($0.location.path, $0.location.line) < ($1.location.path, $1.location.line) }
    
    if results.isEmpty && all.isEmpty {
        return .success("No occurrences found for this USR. Verify the USR is correct using searchSymbol.")
    }
    
    let occurrenceList: [[String: Any]] = results.map { $0.toDetailedDict() }
    
    let output = try formatOccurrenceJSON(occurrenceList, systemCount: all.count - nonSystem.count, staleCount: nonSystem.count - results.count)
    return .success(output)
}
