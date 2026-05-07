import MCP
import Foundation

func registerTools(on server: Server, indexStore: IndexStore) async {
    await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: "loadIndex",
                    description: "Must be called first with the absolute path to the .xcworkspace or .xcodeproj before any other tool. Only needs to be called once per session.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "workspacePath": .object([
                                "type": .string("string"),
                                "description": .string("Absolute path to the .xcworkspace or .xcodeproj"),
                            ]),
                        ]),
                        "required": .array([.string("workspacePath")]),
                    ])
                ),
                Tool(
                    name: "searchSymbol",
                    description: "Use when you know the exact symbol name as it appears in source code. Returns one or more USRs. Pass the exact name — do not guess or approximate. Read the source file first if unsure of spelling.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Exact symbol name as it appears in source code, e.g. viewDidLoad, MyViewController, init"),
                            ]),
                        ]),
                        "required": .array([.string("name")]),
                    ])
                ),
                Tool(
                    name: "searchSymbolPattern",
                    description: "Use when searchSymbol returns no results or you only know a partial name. Performs subsequence matching — e.g. 'mvc' matches 'MyViewController', 'vdl' matches 'viewDidLoad'. Returns USRs like searchSymbol does.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "pattern": .object([
                                "type": .string("string"),
                                "description": .string("Partial or full symbol name to search for. Subsequence matching is on by default: 'mvc' finds 'MyViewController'."),
                            ]),
                            "anchorStart": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, pattern must match from the start of the symbol name. Defaults to false."),
                            ]),
                            "anchorEnd": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, pattern must match to the end of the symbol name. Defaults to false."),
                            ]),
                            "subsequence": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, characters in pattern can match non-consecutively (CamelCase matching). Defaults to true."),
                            ]),
                            "ignoreCase": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, matching is case-insensitive. Defaults to true."),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("pattern")]),
                    ])
                ),
                Tool(
                    name: "symbolAtPosition",
                    description: "Use when reading a file and you want the USR of a symbol at a specific line. More precise than searchSymbol when the name is ambiguous (e.g. init).",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "file": .object([
                                "type": .string("string"),
                                "description": .string("Absolute path to the source file"),
                            ]),
                            "line": .object([
                                "type": .string("integer"),
                                "description": .string("1-based line number"),
                            ]),
                        ]),
                        "required": .array([.string("file"), .string("line")]),
                    ])
                ),
                Tool(
                    name: "getOccurrences",
                    description: "Use after obtaining a USR. Returns every location in the codebase where that symbol is defined, referenced, or called. Use the roles filter to narrow results.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "usr": .object([
                                "type": .string("string"),
                                "description": .string("Unified Symbol Resolution identifier from searchSymbol or symbolAtPosition"),
                            ]),
                            "roles": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")]),
                                "description": .string("Optional role filter: definition, reference, call, override, etc. Defaults to all roles."),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("usr")]),
                    ])
                ),
                Tool(
                    name: "relatedOccurrences",
                    description: "Use to find structural relationships: protocol conformances, method overrides, type extensions. Use this before refactoring a protocol or base class to ensure all conforming types and overrides are found.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "usr": .object([
                                "type": .string("string"),
                                "description": .string("Unified Symbol Resolution identifier"),
                            ]),
                            "roles": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")]),
                                "description": .string("Optional relation filter: overrideOf, baseOf, extendedBy, ibTypeOf, specializationOf, etc. Defaults to all relation roles."),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("usr")]),
                    ])
                ),
                Tool(
                    name: "symbolsInFile",
                    description: "Use to get a structural outline of all symbols defined in a file. Call this before editing a file to understand what it contains, rather than reading and parsing the source text.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "file": .object([
                                "type": .string("string"),
                                "description": .string("Absolute path to the source file"),
                            ]),
                            "roles": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")]),
                                "description": .string("Optional role filter. Defaults to definition only."),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("file")]),
                    ])
                ),
            ])
    }
    
    await server.withMethodHandler(CallTool.self) { params in
        let args = params.arguments ?? [:]
        switch params.name {
        case "loadIndex":
            return try await handleLoadIndex(args, indexStore: indexStore)
        case "searchSymbol":
            return try await handleSearchSymbol(args, indexStore: indexStore)
        case "searchSymbolPattern":
            return try await handleSearchSymbolPattern(args, indexStore: indexStore)
        case "symbolAtPosition":
            return try await handleSymbolAtPosition(args, indexStore: indexStore)
        case "getOccurrences":
            return try await handleGetOccurrences(args, indexStore: indexStore)
        case "relatedOccurrences":
            return try await handleRelatedOccurrences(args, indexStore: indexStore)
        case "symbolsInFile":
            return try await handleSymbolsInFile(args, indexStore: indexStore)
        default:
            return CallTool.Result(
                content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }
}
