import Foundation
import IndexStoreDB

/// Serialises `object` to a pretty-printed JSON string and, when `systemCount > 0`,
/// appends a note explaining that system framework occurrences were excluded.
func formatOccurrenceJSON(_ object: Any, systemCount: Int) throws -> String {
    var text = String(data: try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted), encoding: .utf8) ?? "[]"
    if systemCount > 0 {
        text += "\n\nNote: \(systemCount) system framework occurrence(s) excluded. Pass includeSystem: true to include them."
    }
    return text
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
