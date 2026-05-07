import MCP
import IndexStoreDB
import Foundation

func handleRelatedOccurrences(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let database = await indexStore.database else {
        return CallTool.Result(content: [.text(text: "No index loaded. Call loadIndex first.", annotations: nil, _meta: nil)], isError: true)
    }
    
    guard let usr = args["usr"]?.stringValue else {
        return CallTool.Result(content: [.text(text: "Missing required argument: usr", annotations: nil, _meta: nil)], isError: true)
    }
    
    let roleStrings = args["roles"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let roles = symbolRole(from: roleStrings, defaultRole: .all)
    
    let results = database.occurrences(relatedToUSR: usr, roles: roles)
    let sorted = results.sorted {
        ($0.location.path, $0.location.line) < ($1.location.path, $1.location.line)
    }
    
    let dicts: [[String: String]] = sorted.map { occurrence in
        [
            "file":   occurrence.location.path,
            "line":   String(occurrence.location.line),
            "column": String(occurrence.location.utf8Column),
            "role":   String(describing: occurrence.roles)
        ]
    }
    
    let data = try JSONSerialization.data(withJSONObject: dicts, options: .prettyPrinted)
    let json = String(data: data, encoding: .utf8) ?? "[]"
    
    return CallTool.Result(content: [.text(text: json, annotations: nil, _meta: nil)], isError: false)
}
