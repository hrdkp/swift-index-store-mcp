import MCP
@preconcurrency import IndexStoreDB
import Foundation
import CryptoKit

func handleLoadIndex(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    guard let workspacePath = args["workspacePath"]?.stringValue else {
        return .failure("Missing required argument: workspacePath")
    }
    
    let fm = FileManager.default
    guard fm.fileExists(atPath: workspacePath),
          workspacePath.hasSuffix(".xcworkspace") || workspacePath.hasSuffix(".xcodeproj") else {
        return .failure("Path does not exist or is not an .xcworkspace / .xcodeproj: \(workspacePath)")
    }
    
    if let existing = await indexStore.loadedWorkspacePath {
        if existing == workspacePath {
            return .success("Index already loaded for this workspace.")
        }
        return .failure("Index is already loaded for a different workspace: \(existing). Restart the server to switch projects.")
    }
    
    do {
        let searchBases = derivedDataSearchBases(forWorkspacePath: workspacePath)
        guard let derivedDataDir = findDerivedDataDir(forWorkspacePath: workspacePath, searchBases: searchBases, fm: fm) else {
            let searched = searchBases.map(\.path).joined(separator: "\n  ")
            return .failure("No DerivedData found for this workspace. The project must be built successfully in Xcode at least once before the index is available.\nSearched:\n  \(searched)")
        }
        
        let storeURL = URL(fileURLWithPath: derivedDataDir)
            .appendingPathComponent("Index.noindex/DataStore")
        
        // Use SHA-256 of the workspace path as the cache dir name to avoid length/character issues.
        let cacheBaseURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("IndexStoreMCP")
        let hashHex = SHA256.hash(data: Data(workspacePath.utf8)).map { String(format: "%02x", $0) }.joined()
        let dbURL = cacheBaseURL.appendingPathComponent(hashHex)
        try fm.createDirectory(at: dbURL, withIntermediateDirectories: true)
        
        let libPath = try await indexStoreLibraryPath()
        let library = try IndexStoreLibrary(dylibPath: libPath)
        
        let db = try IndexStoreDB(
            storePath: storeURL.path,
            databasePath: dbURL.path,
            library: library,
            waitUntilDoneInitializing: true,
            listenToUnitEvents: true
        )
        
        await indexStore.setDatabase(db, workspacePath: workspacePath)
        
        return .success("Index loaded: \(storeURL.path)")
    } catch {
        return .failure("Failed to load index: \(error)")
    }
}

// MARK: - DerivedData discovery

private func derivedDataSearchBases(forWorkspacePath workspacePath: String) -> [URL] {
    var bases: [URL] = []
    
    // 1. Xcode preference: custom DerivedData location set in Settings → Locations.
    let xcodePrefURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/com.apple.dt.Xcode.plist")
    if let data = try? Data(contentsOf: xcodePrefURL),
       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
       let customPath = plist["IDECustomDerivedDataLocation"] as? String {
        bases.append(URL(fileURLWithPath: customPath))
    }
    
    // 2. "Relative" mode: DerivedData folder sitting next to the workspace/project.
    bases.append(
        URL(fileURLWithPath: workspacePath)
            .deletingLastPathComponent()
            .appendingPathComponent("DerivedData")
    )
    
    // 3. Default location.
    bases.append(
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
    )
    
    return bases
}

private func findDerivedDataDir(forWorkspacePath workspacePath: String, searchBases: [URL], fm: FileManager) -> String? {
    var candidates: [(path: String, modDate: Date)] = []
    
    for base in searchBases {
        // try? is intentional: a missing base dir (common for relative/custom modes) should
        // be skipped, not treated as a hard error.
        guard let entries = try? fm.contentsOfDirectory(atPath: base.path) else { continue }
        for entry in entries {
            let entryURL = base.appendingPathComponent(entry)
            let infoPlistURL = entryURL.appendingPathComponent("info.plist")
            
            guard let plistData = try? Data(contentsOf: infoPlistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                  let plistWorkspacePath = plist["WorkspacePath"] as? String,
                  plistWorkspacePath == workspacePath else {
                continue
            }
            
            // Pick the entry whose DataStore was most recently written — avoids choosing
            // a stale folder when multiple DerivedData entries match the same workspace.
            let dataStoreURL = entryURL.appendingPathComponent("Index.noindex/DataStore")
            let modDate = (try? fm.attributesOfItem(atPath: dataStoreURL.path))?[.modificationDate] as? Date ?? .distantPast
            candidates.append((path: entryURL.path, modDate: modDate))
        }
    }
    
    return candidates.max(by: { $0.modDate < $1.modDate })?.path
}

// MARK: - IndexStore library discovery

private func indexStoreLibraryPath() async throws -> String {
    var candidates: [String] = []
    
    if let devPath = await xcodeDevPath() {
        let devURL = URL(fileURLWithPath: devPath)
        candidates += [
            devURL
                .appendingPathComponent("Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")
                .path,
            // SharedFrameworks lives one level above the Developer directory.
            devURL
                .deletingLastPathComponent()
                .appendingPathComponent("SharedFrameworks/IndexStore.framework/Versions/A/IndexStore")
                .path,
        ]
    }
    
    // Command Line Tools: fixed install path, checked unconditionally as a final fallback.
    candidates.append("/Library/Developer/CommandLineTools/usr/lib/libIndexStore.dylib")
    
    for path in candidates {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    
    throw LoadIndexError.libraryNotFound(
        "libIndexStore not found. Searched:\n" + candidates.joined(separator: "\n")
    )
}

// Returns the Xcode developer directory without spawning a subprocess when possible.
// Returns nil if neither source resolves a non-empty path (e.g. no Xcode installed).
private func xcodeDevPath() async -> String? {
    if let envPath = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], !envPath.isEmpty {
        return envPath
    }
    
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
            proc.arguments = ["-p"]
            let stdoutPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = Pipe()
            guard (try? proc.run()) != nil else {
                continuation.resume(returning: nil)
                return
            }
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else {
                continuation.resume(returning: nil)
                return
            }
            
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let path = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            continuation.resume(returning: path.isEmpty ? nil : path)
        }
    }
}

private enum LoadIndexError: Error, CustomStringConvertible {
    case libraryNotFound(String)
    
    var description: String {
        switch self {
        case .libraryNotFound(let msg): return msg
        }
    }
}
