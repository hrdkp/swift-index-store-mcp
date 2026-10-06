/// Snippet printed by `--print-agent-instructions`, meant to be pasted into a
/// project's CLAUDE.md / AGENTS.md so agents prefer the index over grep.
enum AgentInstructions {
    static let text = """
    ## Xcode Navigation (index-store-mcp)

    Prefer the index-store-mcp tools over grep/file reads for Swift and Objective-C
    symbol navigation: finding definitions, references and callers, protocol
    conformances, overrides, extensions, and file outlines. Lookups are exact (by USR),
    so there are no false matches from comments, strings or similarly named symbols.
    The index also covers the project's Swift package dependencies, whose sources live
    in DerivedData rather than the repo, so use it to navigate into them too.

    Workflow:
    1. Call `loadIndex` once per session with the .xcworkspace, .xcodeproj, or package directory.
    2. `searchSymbol` (exact name) or `searchSymbolPattern` (partial name) to get a USR.
    3. `getOccurrences` / `relatedOccurrences` with the USR to find usages and conformances.
    4. `symbolAtPosition` to get the USR at a file position; `symbolsInFile` for a file outline.
    5. `refreshIndex` after a build.

    Fall back to grep for non-symbol text such as strings, comments, and config files.
    """
}
