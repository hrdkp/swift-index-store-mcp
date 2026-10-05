import Foundation
import IndexStoreDB

/// Serialises `object` to compact JSON with sorted keys and unescaped slashes.
/// Tool output goes straight into the agent's context, so whitespace and `\/`
/// escapes in every file path are pure token cost. Arrays put one element per
/// line, which stays readable for almost no extra size.
func compactJSON(_ object: Any) throws -> String {
    let options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
    func encode(_ value: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value, options: options), as: UTF8.self)
    }
    guard let array = object as? [Any] else { return try encode(object) }
    if array.isEmpty { return "[]" }
    return "[\n" + (try array.map(encode)).joined(separator: ",\n") + "\n]"
}

/// Serialises `object` with `compactJSON` and, when `systemCount > 0`
/// or `staleCount > 0`, appends a note explaining what was excluded.
func formatOccurrenceJSON(_ object: Any, systemCount: Int, staleCount: Int = 0) throws -> String {
    var text = try compactJSON(object)
    if systemCount > 0 {
        text += "\n\nNote: \(systemCount) system framework occurrence(s) excluded. Pass includeSystem: true to include them."
    }
    if staleCount > 0 {
        text += "\n\nNote: \(staleCount) stale occurrence(s) excluded (source file deleted/renamed, dropped from the build, or edited since last indexed). Run refreshIndex, or rebuild the project, to pick up current data. Pass includeStale: true to include them."
    }
    return text
}

extension Array where Element == SymbolOccurrence {
    /// Drops occurrences that differ only in which index unit reported them,
    /// keeping the copy from the newest unit, in first-seen order. Xcode keeps
    /// the units of every build variant and target that compiled a file, and
    /// never removes old ones, so the same occurrence often comes back several
    /// times with different unit timestamps and module names. Call this on a
    /// query's raw results, before filtering, so result rows and the
    /// excluded-occurrence counts in `formatOccurrenceJSON` notes agree.
    ///
    /// Keeping the newest copy matters for staleness: `isOutOfDate(in:)` judges
    /// each occurrence by its own unit, so a fresh copy must win over a stale one.
    func uniqued() -> [SymbolOccurrence] {
        var newest: [OccurrenceKey: Int] = [:]
        var result: [SymbolOccurrence] = []
        for occurrence in self {
            let key = OccurrenceKey(occurrence)
            if let index = newest[key] {
                if occurrence.location.timestamp > result[index].location.timestamp {
                    result[index] = occurrence
                }
            } else {
                newest[key] = result.count
                result.append(occurrence)
            }
        }
        return result
    }
}

/// Identity of an occurrence as the tools report it: everything except the
/// reporting unit's `timestamp` and `moduleName`.
private struct OccurrenceKey: Hashable {
    let symbol: Symbol
    let path: String
    let line: Int
    let column: Int
    let isSystem: Bool
    let roles: SymbolRole
    let relations: [RelationKey]
    
    struct RelationKey: Hashable {
        let symbol: Symbol
        let roles: SymbolRole
    }
    
    init(_ occurrence: SymbolOccurrence) {
        symbol = occurrence.symbol
        path = occurrence.location.path
        line = occurrence.location.line
        column = occurrence.location.utf8Column
        isSystem = occurrence.location.isSystem
        roles = occurrence.roles
        relations = occurrence.relations.map { RelationKey(symbol: $0.symbol, roles: $0.roles) }
    }
}

extension SymbolOccurrence {
    /// True when the file this occurrence points to no longer exists on disk.
    /// `records/` in the index store is never pruned by Xcode or IndexStoreDB
    /// when a source file is renamed, moved, or deleted, so this is the
    /// dominant staleness case in practice.
    var isOrphaned: Bool {
        !FileManager.default.fileExists(atPath: location.path)
    }
    
    /// True when the file exists but this occurrence is no longer current:
    /// either no unit in `database` references the file anymore (e.g. it was
    /// dropped from target membership without being deleted), or the file was
    /// edited after the unit that produced this occurrence was written.
    ///
    /// Judged per occurrence, by its own unit's `location.timestamp`. Xcode keeps
    /// units from earlier builds and variants alongside current ones, so a file
    /// with one fresh unit can still have old units whose line numbers no longer
    /// match the source. `uniqued()` keeps the newest copy of each occurrence,
    /// so an occurrence that a fresh unit still reports is never dropped.
    func isOutOfDate(in database: IndexStoreDB) -> Bool {
        guard database.dateOfLatestUnitFor(filePath: location.path) != nil else {
            return true
        }
        guard let sourceModDate = try? FileManager.default
            .attributesOfItem(atPath: location.path)[.modificationDate] as? Date
        else { return false } // already caught by isOrphaned if the file is gone
        return sourceModDate > location.timestamp
    }
    
    func isStale(in database: IndexStoreDB) -> Bool {
        isOrphaned || isOutOfDate(in: database)
    }
    
    /// Staleness for results of `symbolOccurrences(inFilePath:)`, judged by the
    /// file's newest unit rather than this occurrence's own unit.
    ///
    /// That query reads only the first unit IndexStoreDB finds for the file,
    /// which may be an old one, so judging by the occurrence's unit would mark
    /// a whole outline stale even when a fresh unit exists. This keeps such
    /// results visible, at the cost of possibly outdated line numbers, until
    /// file queries read the newest unit directly.
    func isStaleForFileQuery(in database: IndexStoreDB) -> Bool {
        if isOrphaned { return true }
        guard let latestUnitDate = database.dateOfLatestUnitFor(filePath: location.path) else {
            return true
        }
        guard let sourceModDate = try? FileManager.default
            .attributesOfItem(atPath: location.path)[.modificationDate] as? Date
        else { return false }
        return sourceModDate > latestUnitDate
    }
}

extension SymbolOccurrence {
    /// Compact dict for canonical symbol lookups (one result per USR).
    /// Keys: usr, name, kind, location ("path:line"), subKind (when present).
    /// Used by SearchSymbol and SearchSymbolPattern.
    func toCanonicalDict() -> [String: String] {
        var dict: [String: String] = [
            "usr":      symbol.usr,
            "name":     symbol.name,
            "kind":     String(describing: symbol.kind),
            "location": "\(location.path):\(location.line)",
        ]
        if symbol.subKind != .none {
            dict["subKind"] = String(describing: symbol.subKind)
        }
        return dict
    }
    
    /// Detailed dict for full occurrence listings.
    /// Keys: file, line, column, role, name, kind, subKind (when present),
    ///       relations (when non-empty).
    /// Used by GetOccurrences and RelatedOccurrences.
    func toDetailedDict() -> [String: Any] {
        var dict: [String: Any] = [
            "file":   location.path,
            "line":   location.line,
            "column": location.utf8Column,
            "role":   String(describing: roles),
            "name":   symbol.name,
            "kind":   String(describing: symbol.kind),
        ]
        if symbol.subKind != .none {
            dict["subKind"] = String(describing: symbol.subKind)
        }
        if !relations.isEmpty {
            dict["relations"] = relations.map { relation in
                [
                    "usr":  relation.symbol.usr,
                    "name": relation.symbol.name,
                    "kind": String(describing: relation.symbol.kind),
                    "role": String(describing: relation.roles),
                ]
            }
        }
        return dict
    }
}
