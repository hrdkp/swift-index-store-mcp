import MCP
import Foundation

// MARK: - ToolName

/// The authoritative set of tool names exposed by this server.
///
/// Using a `String` enum means:
/// - `ListTools` uses `ToolName.<case>.rawValue` — no free-form literals.
/// - The `CallTool` switch is over the enum — the compiler enforces exhaustiveness,
///   so adding a case without a handler (or vice-versa) is a build error.
enum ToolName: String {
    case loadIndex
    case searchSymbol
    case searchSymbolPattern
    case symbolAtPosition
    case getOccurrences
    case relatedOccurrences
    case symbolsInFile
    case refreshIndex
}

// MARK: - Registration

func registerTools(on server: Server, indexStore: IndexStore) async {
    await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: ToolName.loadIndex.rawValue,
                    description: "Start here. Loads the Xcode index so the other tools can answer semantic questions about Swift and Objective-C code: definitions, references, callers, protocol conformances, overrides. Must be called once per session before any other tool, with the .xcworkspace, .xcodeproj, or Swift Package directory. The project must have been built in Xcode at least once. Typical workflow: loadIndex → searchSymbol/searchSymbolPattern → getOccurrences/relatedOccurrences. Call refreshIndex after a build to pick up changes.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "workspacePath": .object([
                                "type": .string("string"),
                                "description": .string("Absolute path to the .xcworkspace, .xcodeproj, or Swift Package directory"),
                            ]),
                        ]),
                        "required": .array([.string("workspacePath")]),
                    ])
                ),
                Tool(
                    name: ToolName.searchSymbol.rawValue,
                    description: "Find a Swift/Objective-C symbol by exact name and get its USR(s). Prefer this over grep to locate where a type, method or property is defined or used: results are real symbols, not text matches in comments or strings. For types and properties, use the bare name (e.g. MyViewController, isLoading). For methods, you can use either the bare name (e.g. viewDidLoad) or the full signature with labels (e.g. tableView(_:numberOfRowsInSection:)). Falls back to prefix matching if no exact match is found. Pass a returned USR to getOccurrences or relatedOccurrences.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Symbol name — e.g. MyViewController, viewDidLoad, tableView(_:numberOfRowsInSection:)"),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("name")]),
                    ])
                ),
                Tool(
                    name: ToolName.searchSymbolPattern.rawValue,
                    description: "Fuzzy symbol search for when searchSymbol returns no results or you only know a partial name. Performs subsequence matching — e.g. 'mvc' matches 'MyViewController'. Results may include dependencies; use anchorStart/anchorEnd and longer patterns to narrow them. Returns USRs for getOccurrences or relatedOccurrences.",
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
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("pattern")]),
                    ])
                ),
                Tool(
                    name: ToolName.symbolAtPosition.rawValue,
                    description: "Get the symbol at a specific file position, including its USR. Use when you are reading a file and need to know what a name refers to, or when searchSymbol is ambiguous (e.g. init, configure, handle). Returns the single closest symbol at or before the given column.",
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
                            "column": .object([
                                "type": .string("integer"),
                                "description": .string("1-based UTF-8 column offset"),
                            ]),
                            "includeSystem": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches in system frameworks (UIKit, Foundation, etc.). Defaults to false."),
                            ]),
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include matches whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("file"), .string("line"), .string("column")]),
                    ])
                ),
                Tool(
                    name: ToolName.getOccurrences.rawValue,
                    description: "Find every place a symbol is defined, referenced, or called, given its USR. Prefer this over grepping for the name: it finds usages across the whole codebase without false matches from comments, strings, or similarly named symbols. Use the roles filter (e.g. definition, reference, call) to narrow results, such as listing only callers. Get the USR from searchSymbol, searchSymbolPattern, or symbolAtPosition.",
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
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("usr")]),
                    ])
                ),
                Tool(
                    name: ToolName.relatedOccurrences.rawValue,
                    description: "Find structural relationships for a symbol by USR: protocol conformances, method overrides, type extensions. Answers \"what will break if I change this?\" — use it before refactoring a protocol, base class, or overridable method so every conforming type and override is found.",
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
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("usr")]),
                    ])
                ),
                Tool(
                    name: ToolName.symbolsInFile.rawValue,
                    description: "Get a structural outline of a file — symbol names, kinds, USRs, and line numbers — without reading the source. Call this before opening a large Swift/Objective-C file to find the part you need, and to keep your context small.",
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
                            "includeStale": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, include occurrences whose source file was deleted/renamed, dropped from the build, or edited since last indexed. Defaults to false."),
                            ]),
                        ]),
                        "required": .array([.string("file")]),
                    ])
                ),
                Tool(
                    name: ToolName.refreshIndex.rawValue,
                    description: "Polls the index store for changes written since the last scan and updates the in-memory database. Call this after building in Xcode (or xcodebuild) completes, or whenever query results look stale after source changes.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([:]),
                        "required": .array([]),
                    ])
                ),
            ])
    }
    
    await server.withMethodHandler(CallTool.self) { params in
        let args = params.arguments ?? [:]
        guard let tool = ToolName(rawValue: params.name) else {
            return .failure("Unknown tool: \(params.name)")
        }
        switch tool {
        case .loadIndex:
            return try await handleLoadIndex(args, indexStore: indexStore)
        case .searchSymbol:
            return try await handleSearchSymbol(args, indexStore: indexStore)
        case .searchSymbolPattern:
            return try await handleSearchSymbolPattern(args, indexStore: indexStore)
        case .symbolAtPosition:
            return try await handleSymbolAtPosition(args, indexStore: indexStore)
        case .getOccurrences:
            return try await handleGetOccurrences(args, indexStore: indexStore)
        case .relatedOccurrences:
            return try await handleRelatedOccurrences(args, indexStore: indexStore)
        case .symbolsInFile:
            return try await handleSymbolsInFile(args, indexStore: indexStore)
        case .refreshIndex:
            return try await handleRefreshIndex(indexStore: indexStore)
        }
    }
}
