import MCP
import IndexStoreDB
import Foundation

func handleGetOccurrences(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let usr = args["usr"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: usr", annotations: nil, _meta: nil)], isError: true)
    }
    
    let roleStrings = args["roles"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let (roles, unknownRoles) = symbolRole(from: roleStrings, defaultRole: .all)
    if !unknownRoles.isEmpty {
        return CallTool.Result(
            content: [.text(text: "Unknown role(s): \(unknownRoles.joined(separator: ", ")). Valid roles: declaration, definition, reference, read, write, call, dynamic, addressOf, implicit, childOf, baseOf, overrideOf, receivedBy, calledBy, extendedBy, accessorOf, containedBy, ibTypeOf, specializationOf, canonical", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    let results = database.occurrences(ofUSR: usr, roles: roles)
    let sorted = results.sorted {
        ($0.location.path, $0.location.line) < ($1.location.path, $1.location.line)
    }
    
    let occurrenceList: [[String: String]] = sorted.map { occurrence in
        [
            "file":   occurrence.location.path,
            "line":   String(occurrence.location.line),
            "column": String(occurrence.location.utf8Column),
            "role":   String(describing: occurrence.roles)
        ]
    }
    
    let jsonData = try JSONSerialization.data(withJSONObject: occurrenceList, options: .prettyPrinted)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
    
    return CallTool.Result(content: [.text(text: jsonString, annotations: nil, _meta: nil)], isError: false)
}
