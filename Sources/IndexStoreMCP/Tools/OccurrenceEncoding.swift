import Foundation
import IndexStoreDB

/// Serialises `object` to compact JSON with sorted keys and unescaped slashes.
/// Tool output goes straight into the agent's context, so whitespace and `\/`
/// escapes in every file path are pure token cost. Arrays put one element per
/// line, which stays readable for almost no extra size.
///
/// Identical array elements are dropped, keeping the first. The index holds one
/// unit per build variant (e.g. per architecture, or per target sharing a file),
/// and each unit reports the same occurrence, so exact duplicates are common.
func compactJSON(_ object: Any) throws -> String {
    let options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
    func encode(_ value: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value, options: options), as: UTF8.self)
    }
    guard let array = object as? [Any] else { return try encode(object) }
    if array.isEmpty { return "[]" }
    var seen = Set<String>()
    let lines = try array.map(encode).filter { seen.insert($0).inserted }
    return "[\n" + lines.joined(separator: ",\n") + "\n]"
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
    /// edited more recently than the newest unit that indexed it.
    ///
    /// Uses the latest unit date across *all* units for this path, rather than
    /// this occurrence's own `location.timestamp`, so a file compiled into
    /// multiple units (e.g. shared between an app and test target) isn't
    /// flagged stale just because the specific unit that produced this
    /// occurrence hasn't been rebuilt as recently as another one that has.
    func isOutOfDate(in database: IndexStoreDB) -> Bool {
        guard let latestUnitDate = database.dateOfLatestUnitFor(filePath: location.path) else {
            return true
        }
        guard let sourceModDate = try? FileManager.default
            .attributesOfItem(atPath: location.path)[.modificationDate] as? Date
        else { return false } // already caught by isOrphaned if the file is gone
        return sourceModDate > latestUnitDate
    }
    
    func isStale(in database: IndexStoreDB) -> Bool {
        isOrphaned || isOutOfDate(in: database)
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
