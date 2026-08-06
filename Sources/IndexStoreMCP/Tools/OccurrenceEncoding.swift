import Foundation
import IndexStoreDB

/// Serialises `object` to a pretty-printed JSON string and, when `systemCount > 0`
/// or `staleCount > 0`, appends a note explaining what was excluded.
func formatOccurrenceJSON(_ object: Any, systemCount: Int, staleCount: Int = 0) throws -> String {
    var text = String(data: try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted), encoding: .utf8) ?? "[]"
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
