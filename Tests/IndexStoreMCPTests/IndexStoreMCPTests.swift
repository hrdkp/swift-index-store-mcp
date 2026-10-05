import Testing
import Foundation
import MCP
@preconcurrency import IndexStoreDB

@testable import IndexStoreMCP

// MARK: - Helpers

private let workspacePath: String = {
    // Walk up from the test executable to find the package root (directory containing Package.swift).
    var url = URL(fileURLWithPath: #filePath)
    while url.path != "/" {
        url = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return url.path
        }
    }
    fatalError("Could not find Package.swift in any parent directory of \(#filePath)")
}()
private let indexStoreFile = "\(workspacePath)/Sources/IndexStoreMCP/IndexStore.swift"

extension CallTool.Result {
    var text: String {
        content.compactMap {
            if case .text(let text, _, _) = $0 { return text }
            return nil
        }.joined()
    }
    
    var isFailure: Bool { isError == true }
}

/// USR of the `IndexStore` actor, looked up rather than hard-coded: its module
/// segment depends on the Xcode version that built the index (Xcode 26 names the
/// module after the `index-store-mcp` product, Xcode 27 after the target).
private func indexStoreActorUSR(in store: IndexStore) async throws -> String {
    let database = try #require(await store.database)
    let definition = database.canonicalOccurrences(ofName: "IndexStore")
        .first { $0.location.path == indexStoreFile }
    return try #require(definition?.symbol.usr, "IndexStore actor not found in \(indexStoreFile)")
}

private func loadedIndexStore() async throws -> IndexStore {
    let store = IndexStore()
    let result = try await handleLoadIndex(
        ["workspacePath": .string(workspacePath)],
        indexStore: store
    )
    #expect(!result.isFailure, "loadIndex failed: \(result.text)")
    return store
}

// MARK: - loadIndex

@Suite("loadIndex")
struct LoadIndexTests {
    @Test func loadSucceeds() async throws {
        let store = IndexStore()
        let result = try await handleLoadIndex(
            ["workspacePath": .string(workspacePath)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("Index loaded"))
        #expect(result.text.contains("libIndexStore: "))
    }
    
    /// Ceiling check: a compiler newer than the pinned indexstore-db can record
    /// symbol kinds the pin doesn't know, which surface as `.unknown`. CI runs this
    /// on the newest Xcode, so a failure means the pin needs bumping.
    @Test func noUnknownSymbolKinds() async throws {
        let store = try await loadedIndexStore()
        let database = try #require(await store.database)
        let sources = try #require(FileManager.default.enumerator(atPath: "\(workspacePath)/Sources"))
        let files = sources.compactMap { $0 as? String }
            .filter { $0.hasSuffix(".swift") }
            .map { "\(workspacePath)/Sources/\($0)" }
        #expect(!files.isEmpty)
        
        let occurrences = files.flatMap { database.symbolOccurrences(inFilePath: $0) }
        #expect(!occurrences.isEmpty, "no symbols indexed; was the package built with xcodebuild?")
        let unknown = occurrences.filter { $0.symbol.kind == .unknown }
        #expect(unknown.isEmpty, "unknown symbol kinds: \(unknown.map { "\($0.symbol.name) at \($0.location)" })")
    }
    
    @Test func idempotentForSameWorkspace() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleLoadIndex(
            ["workspacePath": .string(workspacePath)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("already loaded"))
    }
    
    @Test func rejectsDifferentWorkspace() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleLoadIndex(
            ["workspacePath": .string("/tmp")],
            indexStore: store
        )
        #expect(result.isFailure)
        #expect(result.text.contains("already loaded for a different workspace"))
    }
    
    @Test func rejectsNonexistentPath() async throws {
        let store = IndexStore()
        let result = try await handleLoadIndex(
            ["workspacePath": .string("/nonexistent/path")],
            indexStore: store
        )
        #expect(result.isFailure)
        #expect(result.text.contains("does not exist"))
    }
    
    @Test func rejectsRegularFile() async throws {
        let store = IndexStore()
        let result = try await handleLoadIndex(
            ["workspacePath": .string(indexStoreFile)],
            indexStore: store
        )
        #expect(result.isFailure)
    }
}

// MARK: - searchSymbol

@Suite("searchSymbol")
struct SearchSymbolTests {
    @Test func findsKnownSymbol() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSearchSymbol(
            ["name": .string("IndexStore")],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains(try await indexStoreActorUSR(in: store)))
    }
    
    @Test func returnsMessageForUnknownSymbol() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSearchSymbol(
            ["name": .string("CompletelyBogusSymbolName12345")],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("No match found"))
    }
    
    @Test func fallsBackToPrefixMatchForBareMethods() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSearchSymbol(
            ["name": .string("reserveLoading")],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("reserveLoading(workspacePath:)"))
    }
    
    @Test func requiresLoadedIndex() async throws {
        let store = IndexStore()
        let result = try await handleSearchSymbol(
            ["name": .string("IndexStore")],
            indexStore: store
        )
        #expect(result.isFailure)
        #expect(result.text.contains("No index loaded"))
    }
}

// MARK: - symbolAtPosition

@Suite("symbolAtPosition")
struct SymbolAtPositionTests {
    @Test func findsSymbolAtExactPosition() async throws {
        let store = try await loadedIndexStore()
        // "actor IndexStore" is at line 3, column 7
        let result = try await handleSymbolAtPosition(
            ["file": .string(indexStoreFile), "line": .int(3), "column": .int(7)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("IndexStore"))
    }
    
    @Test func columnSnapsToNearestSymbol() async throws {
        let store = try await loadedIndexStore()
        // Column 10 is past the start of "IndexStore" on line 3 — should still match it
        let result = try await handleSymbolAtPosition(
            ["file": .string(indexStoreFile), "line": .int(3), "column": .int(10)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("IndexStore"))
    }
    
    @Test func returnsMessageForEmptyLine() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSymbolAtPosition(
            ["file": .string(indexStoreFile), "line": .int(9999), "column": .int(1)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("No symbol found"))
    }
    
    @Test func requiresColumnArg() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSymbolAtPosition(
            ["file": .string(indexStoreFile), "line": .int(3)],
            indexStore: store
        )
        #expect(result.isFailure)
        #expect(result.text.contains("column"))
    }
}

// MARK: - symbolsInFile

@Suite("symbolsInFile")
struct SymbolsInFileTests {
    @Test func listsSymbolsInKnownFile() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleSymbolsInFile(
            ["file": .string(indexStoreFile)],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("IndexStore"))
        #expect(result.text.contains("reserveLoading"))
        #expect(result.text.contains("setDatabase"))
        #expect(result.text.contains("loadEnded"))
    }
}

// MARK: - getOccurrences

@Suite("getOccurrences")
struct GetOccurrencesTests {
    @Test func findsOccurrencesForKnownUSR() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleGetOccurrences(
            ["usr": .string(try await indexStoreActorUSR(in: store))],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("IndexStore.swift"))
    }
    
    @Test func returnsMessageForBogusUSR() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleGetOccurrences(
            ["usr": .string("s:totally_bogus_usr")],
            indexStore: store
        )
        #expect(!result.isFailure)
        #expect(result.text.contains("No occurrences found"))
    }
    
    @Test func rejectsUnknownRoles() async throws {
        let store = try await loadedIndexStore()
        let result = try await handleGetOccurrences(
            ["usr": .string(try await indexStoreActorUSR(in: store)), "roles": .array([.string("madeUpRole")])],
            indexStore: store
        )
        #expect(result.isFailure)
        #expect(result.text.contains("Unknown role"))
    }
}

// MARK: - reserveLoad concurrency

@Suite("IndexStore actor")
struct IndexStoreActorTests {
    @Test func reserveLoadBlocksConcurrentCallers() async throws {
        let store = IndexStore()
        let first = await store.reserveLoading(workspacePath: workspacePath)
        #expect(first == .reserved)
        
        let second = await store.reserveLoading(workspacePath: workspacePath)
        #expect(second == .loadInProgress)
        
        await store.loadEnded()
        
        // After loadEnded, a new reserve should succeed
        let third = await store.reserveLoading(workspacePath: workspacePath)
        #expect(third == .reserved)
    }
    
    @Test func alreadyLoadedSamePath() async throws {
        let store = try await loadedIndexStore()
        let result = await store.reserveLoading(workspacePath: workspacePath)
        if case .alreadyLoaded(samePath: let same) = result {
            #expect(same == true)
        } else {
            Issue.record("Expected .alreadyLoaded, got \(result)")
        }
    }
    
    @Test func alreadyLoadedDifferentPath() async throws {
        let store = try await loadedIndexStore()
        let result = await store.reserveLoading(workspacePath: "/some/other/path")
        if case .alreadyLoaded(samePath: let same) = result {
            #expect(same == false)
        } else {
            Issue.record("Expected .alreadyLoaded, got \(result)")
        }
    }
}

// MARK: - staleness checks (isOrphaned / isOutOfDate / isStale)

private func makeOccurrence(path: String) -> SymbolOccurrence {
    SymbolOccurrence(
        symbol: Symbol(usr: "s:test", name: "Test", kind: .struct, language: .swift),
        location: SymbolLocation(path: path, timestamp: .distantPast, moduleName: "Test", line: 1, utf8Column: 1),
        roles: .definition,
        symbolProvider: .swift
    )
}

@Suite("staleness checks")
struct StalenessTests {
    @Test func isOrphanedForPathThatNeverExisted() {
        let occurrence = makeOccurrence(path: "/nonexistent/path/Ghost.swift")
        #expect(occurrence.isOrphaned)
    }
    
    @Test func isOrphanedForDeletedFile() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Deleted-\(UUID()).swift")
        try "// temp".write(to: tempURL, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: tempURL)
        
        let occurrence = makeOccurrence(path: tempURL.path)
        #expect(occurrence.isOrphaned)
    }
    
    @Test func notOrphanedForExistingFile() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Existing-\(UUID()).swift")
        try "// temp".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let occurrence = makeOccurrence(path: tempURL.path)
        #expect(!occurrence.isOrphaned)
    }
    
    @Test func outOfDateForFileWithNoCurrentUnit() async throws {
        let store = try await loadedIndexStore()
        let database = try #require(await store.database)
        
        // A path IndexStoreDB has never seen a unit for — same signal as a
        // file dropped from target membership without being deleted.
        let occurrence = makeOccurrence(path: "/tmp/never-indexed-\(UUID()).swift")
        #expect(occurrence.isOutOfDate(in: database))
        #expect(occurrence.isStale(in: database))
    }
    
    @Test func notOutOfDateForUnmodifiedIndexedFile() async throws {
        let store = try await loadedIndexStore()
        let database = try #require(await store.database)
        
        // indexStoreFile is a real source file in this project's own index,
        // untouched since the last build — the normal in-sync case.
        let occurrence = makeOccurrence(path: indexStoreFile)
        #expect(!occurrence.isOrphaned)
        #expect(!occurrence.isOutOfDate(in: database))
        #expect(!occurrence.isStale(in: database))
    }
    
    @Test func outOfDateForFileEditedSinceLastIndexed() async throws {
        let store = try await loadedIndexStore()
        let database = try #require(await store.database)
        
        // A file this suite doesn't share with other tests, so bumping its
        // mtime can't race a concurrently-running test that reads it.
        let trackedFile = "\(workspacePath)/Sources/IndexStoreMCP/Tools/RoleMapping.swift"
        let originalModDate = try #require(
            FileManager.default.attributesOfItem(atPath: trackedFile)[.modificationDate] as? Date
        )
        defer {
            try? FileManager.default.setAttributes([.modificationDate: originalModDate], ofItemAtPath: trackedFile)
        }
        let future = Date().addingTimeInterval(60 * 60 * 24 * 365)
        try FileManager.default.setAttributes([.modificationDate: future], ofItemAtPath: trackedFile)
        
        let occurrence = makeOccurrence(path: trackedFile)
        #expect(!occurrence.isOrphaned)
        #expect(occurrence.isOutOfDate(in: database))
        #expect(occurrence.isStale(in: database))
    }
}

// MARK: - compactJSON

@Suite("compactJSON")
struct CompactJSONTests {
    @Test func oneSortedObjectPerLineWithUnescapedSlashes() throws {
        let output = try compactJSON([["name": "Foo", "file": "/a/b.swift"], ["name": "Bar", "file": "/c.swift"]])
        #expect(output == "[\n{\"file\":\"/a/b.swift\",\"name\":\"Foo\"},\n{\"file\":\"/c.swift\",\"name\":\"Bar\"}\n]")
    }
    
    @Test func dropsExactDuplicatesKeepingOrder() throws {
        let a = ["name": "A", "line": 1] as [String: Any]
        let b = ["name": "B", "line": 2] as [String: Any]
        let aOtherLine = ["name": "A", "line": 3] as [String: Any]
        let output = try compactJSON([a, b, a, aOtherLine, b])
        #expect(output == "[\n{\"line\":1,\"name\":\"A\"},\n{\"line\":2,\"name\":\"B\"},\n{\"line\":3,\"name\":\"A\"}\n]")
    }
    
    @Test func emptyArrayAndObject() throws {
        #expect(try compactJSON([Any]()) == "[]")
        #expect(try compactJSON(["line": 3, "kind": "class"]) == "{\"kind\":\"class\",\"line\":3}")
    }
}

// MARK: - stale-count note in formatOccurrenceJSON

@Suite("formatOccurrenceJSON stale note")
struct FormatOccurrenceJSONStaleTests {
    @Test func appendsNoteAndCountWhenStaleExcluded() throws {
        let output = try formatOccurrenceJSON([["name": "Foo"]], systemCount: 0, staleCount: 3)
        #expect(output.contains("3 stale occurrence(s) excluded"))
        #expect(output.contains("includeStale: true"))
    }
    
    @Test func omitsNoteWhenNothingStaleExcluded() throws {
        let output = try formatOccurrenceJSON([["name": "Foo"]], systemCount: 0, staleCount: 0)
        #expect(!output.contains("stale occurrence"))
    }
    
    @Test func includesBothNotesWhenSystemAndStaleExcluded() throws {
        let output = try formatOccurrenceJSON([["name": "Foo"]], systemCount: 2, staleCount: 1)
        #expect(output.contains("2 system framework occurrence(s) excluded"))
        #expect(output.contains("1 stale occurrence(s) excluded"))
    }
}
