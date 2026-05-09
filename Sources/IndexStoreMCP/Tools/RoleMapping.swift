import IndexStoreDB

// MARK: - RoleName

/// Typed representation of every role string the tools accept.
///
/// Using a `String` enum with `CaseIterable` gives us three things for free:
/// - Input validation via `RoleName(rawValue:)` — no manual string switch needed.
/// - `validRoleNames` derived from `allCases` — always in sync with the cases.
/// - Compiler-exhaustiveness on the `symbolRole` switch — adding a case without
///   mapping it to an `IndexStoreDB.SymbolRole` is a build error.
enum RoleName: String, CaseIterable {
    case declaration
    case definition
    case reference
    case read
    case write
    case call
    case dynamic
    case addressOf
    case implicit
    case childOf
    case baseOf
    case overrideOf
    case receivedBy
    case calledBy
    case extendedBy
    case accessorOf
    case containedBy
    case ibTypeOf
    case specializationOf
    case canonical
    
    var symbolRole: SymbolRole {
        switch self {
        case .declaration:      return .declaration
        case .definition:       return .definition
        case .reference:        return .reference
        case .read:             return .read
        case .write:            return .write
        case .call:             return .call
        case .dynamic:          return .dynamic
        case .addressOf:        return .addressOf
        case .implicit:         return .implicit
        case .childOf:          return .childOf
        case .baseOf:           return .baseOf
        case .overrideOf:       return .overrideOf
        case .receivedBy:       return .receivedBy
        case .calledBy:         return .calledBy
        case .extendedBy:       return .extendedBy
        case .accessorOf:       return .accessorOf
        case .containedBy:      return .containedBy
        case .ibTypeOf:         return .ibTypeOf
        case .specializationOf: return .specializationOf
        case .canonical:        return .canonical
        }
    }
}

// MARK: - Public interface

/// Comma-separated list of all valid role strings, derived from `RoleName.allCases`.
/// Used in error messages; stays in sync with the enum automatically.
let validRoleNames = RoleName.allCases.map(\.rawValue).joined(separator: ", ")

/// Returns the `SymbolRole` bitmask for the given strings, plus any unrecognised strings.
/// Callers should surface unrecognised strings as an error to avoid silent no-op queries.
func symbolRole(from strings: [String], defaultRole: SymbolRole) -> (role: SymbolRole, unknown: [String]) {
    guard !strings.isEmpty else { return (defaultRole, []) }
    var role: SymbolRole = []
    var unknown: [String] = []
    for s in strings {
        if let name = RoleName(rawValue: s) {
            role.insert(name.symbolRole)
        } else {
            unknown.append(s)
        }
    }
    return (role, unknown)
}
