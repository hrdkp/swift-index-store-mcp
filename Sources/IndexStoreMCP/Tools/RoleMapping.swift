import IndexStoreDB

// Returns the SymbolRole bitmask for the given strings, plus any unrecognized strings.
// Callers should surface unrecognized strings as an error to avoid silent no-op queries.
func symbolRole(from strings: [String], defaultRole: SymbolRole) -> (role: SymbolRole, unknown: [String]) {
    guard !strings.isEmpty else { return (defaultRole, []) }
    var role: SymbolRole = []
    var unknown: [String] = []
    for s in strings {
        switch s {
        case "declaration":       role.insert(.declaration)
        case "definition":        role.insert(.definition)
        case "reference":         role.insert(.reference)
        case "read":              role.insert(.read)
        case "write":             role.insert(.write)
        case "call":              role.insert(.call)
        case "dynamic":           role.insert(.dynamic)
        case "addressOf":         role.insert(.addressOf)
        case "implicit":          role.insert(.implicit)
        case "childOf":           role.insert(.childOf)
        case "baseOf":            role.insert(.baseOf)
        case "overrideOf":        role.insert(.overrideOf)
        case "receivedBy":        role.insert(.receivedBy)
        case "calledBy":          role.insert(.calledBy)
        case "extendedBy":        role.insert(.extendedBy)
        case "accessorOf":        role.insert(.accessorOf)
        case "containedBy":       role.insert(.containedBy)
        case "ibTypeOf":          role.insert(.ibTypeOf)
        case "specializationOf":  role.insert(.specializationOf)
        case "canonical":         role.insert(.canonical)
        default:                  unknown.append(s)
        }
    }
    return (role, unknown)
}
