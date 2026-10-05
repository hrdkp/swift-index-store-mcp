import MCP
@preconcurrency import IndexStoreDB
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
    let includeStale = args["includeStale"]?.boolValue ?? false
    
    var kind: IndexSymbolKind?
    database.forEachSymbolOccurrence(byUSR: usr, roles: .all) { occurrence in
        kind = occurrence.symbol.kind
        return false
    }
    
    let all: [(occurrence: SymbolOccurrence, via: String?)]
    if let kind, typeKinds.contains(kind) {
        all = structuralOccurrences(ofType: usr, roles: roles, includeSystem: includeSystem, in: database)
    } else {
        all = database.occurrences(relatedToUSR: usr, roles: roles).uniqued().map { ($0, nil) }
    }
    let nonSystem = all.filter { includeSystem || !$0.occurrence.location.isSystem }
    let results = nonSystem
        .filter { includeStale || !$0.occurrence.isStale(in: database) }
        .sorted { ($0.occurrence.location.path, $0.occurrence.location.line) < ($1.occurrence.location.path, $1.occurrence.location.line) }
    
    if results.isEmpty && all.isEmpty {
        return .success("No related occurrences found. This symbol may not have conformances, subclasses, overrides, or extensions.")
    }
    
    let dicts: [[String: Any]] = results.map { result in
        var dict = result.occurrence.toDetailedDict()
        if let via = result.via {
            dict["via"] = via
        }
        return dict
    }
    
    let output = try formatOccurrenceJSON(dicts, systemCount: all.count - nonSystem.count, staleCount: nonSystem.count - results.count)
    return .success(output)
}

/// Kinds whose relationships are indexed on references *to* the symbol: a
/// conformance or subclass is a reference to the protocol or class with the
/// `baseOf` role, and an extension is a reference to the type with `extendedBy`.
/// `occurrences(relatedToUSR:)` doesn't find these; it finds overrides and
/// implementations, which are related to the member they override.
private let typeKinds: Set<IndexSymbolKind> = [.class, .struct, .enum, .protocol]

/// Conformances, subclasses, and extensions of the type or protocol `usr`.
///
/// Follows sub-protocols and subclasses so indirect conformers and subclasses
/// are included, each tagged with `via`: the name of the protocol or class it
/// was reached through. Only `usr`'s own extensions are returned, not those of
/// its sub-protocols or subclasses. System code is only followed when
/// `includeSystem` is set, since system protocols have very large hierarchies.
private func structuralOccurrences(
    ofType usr: String,
    roles: SymbolRole,
    includeSystem: Bool,
    in database: IndexStoreDB
) -> [(occurrence: SymbolOccurrence, via: String?)] {
    let structuralRoles = roles.intersection([.baseOf, .extendedBy])
    var results: [(occurrence: SymbolOccurrence, via: String?)] = []
    var visited: Set<String> = [usr]
    var queue: [(usr: String, roles: SymbolRole, via: String?)] = [(usr, structuralRoles, nil)]
    while !queue.isEmpty {
        let current = queue.removeFirst()
        guard !current.roles.isEmpty else { continue }
        for occurrence in database.occurrences(ofUSR: current.usr, roles: current.roles).uniqued() {
            results.append((occurrence, current.via))
            guard includeSystem || !occurrence.location.isSystem else { continue }
            for relation in occurrence.relations
            where relation.roles.contains(.baseOf)
                && (relation.symbol.kind == .protocol || relation.symbol.kind == .class)
                && visited.insert(relation.symbol.usr).inserted {
                queue.append((relation.symbol.usr, structuralRoles.intersection(.baseOf), relation.symbol.name))
            }
        }
    }
    return results
}
