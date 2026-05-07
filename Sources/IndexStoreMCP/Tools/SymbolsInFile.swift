import MCP
import IndexStoreDB
import Foundation

func handleSymbolsInFile(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let file = args["file"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: file", annotations: nil, _meta: nil)], isError: true)
    }
    
    let roleStrings = args["roles"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let (roles, unknownRoles) = symbolRole(from: roleStrings, defaultRole: .definition)
    if !unknownRoles.isEmpty {
        return CallTool.Result(
            content: [.text(text: "Unknown role(s): \(unknownRoles.joined(separator: ", ")). Valid roles: declaration, definition, reference, read, write, call, dynamic, addressOf, implicit, childOf, baseOf, overrideOf, receivedBy, calledBy, extendedBy, accessorOf, containedBy, ibTypeOf, specializationOf, canonical", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    let all = database.symbolOccurrences(inFilePath: file)
    let filtered = all.filter { !$0.roles.intersection(roles).isEmpty }
    let sorted = filtered.sorted { $0.location.line < $1.location.line }
    
    let items: [[String: String]] = sorted.map { occurrence in
        [
            "name":   occurrence.symbol.name,
            "usr":    occurrence.symbol.usr,
            "kind":   String(describing: occurrence.symbol.kind),
            "line":   String(occurrence.location.line),
            "column": String(occurrence.location.utf8Column),
            "role":   String(describing: occurrence.roles)
        ]
    }
    
    let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
    let text = String(decoding: data, as: UTF8.self)
    
    return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
}
