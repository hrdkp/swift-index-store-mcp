import MCP
import IndexStoreDB
import Foundation

func handleLoadIndex(_ args: [String: Value], indexStore: IndexStore) async throws -> CallTool.Result {
    // 1. Extract workspacePath
    guard let workspacePath = args["workspacePath"]?.stringValue else {
        return CallTool.Result(
            content: [.text(text: "Missing required argument: workspacePath", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    // 2. Validate path exists and has the right extension
    let fm = FileManager.default
    guard fm.fileExists(atPath: workspacePath),
          workspacePath.hasSuffix(".xcworkspace") || workspacePath.hasSuffix(".xcodeproj") else {
        return CallTool.Result(
            content: [.text(text: "Path does not exist or is not an .xcworkspace / .xcodeproj: \(workspacePath)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    // 3. Find matching DerivedData directory
    let derivedDataBase = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/Xcode/DerivedData").path
    
    var matchedDerivedDataDir: String? = nil
    
    if let entries = try? fm.contentsOfDirectory(atPath: derivedDataBase) {
        for entry in entries {
            let entryPath = derivedDataBase + "/" + entry
            let infoPlistPath = entryPath + "/info.plist"
            guard let plist = NSDictionary(contentsOfFile: infoPlistPath),
                  let plistWorkspacePath = plist["WorkspacePath"] as? String,
                  plistWorkspacePath == workspacePath else {
                continue
            }
            matchedDerivedDataDir = entryPath
            break
        }
    }
    
    guard let derivedDataDir = matchedDerivedDataDir else {
        return CallTool.Result(
            content: [.text(text: "No DerivedData found for this workspace. Has the project been built in Xcode?", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    
    // 4–8. Construct paths, load library, initialise DB, store in actor
    do {
        // 4. Construct paths
        let storePath = derivedDataDir + "/Index.noindex/DataStore"
        
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IndexStoreMCP").path
        let sanitized = workspacePath.replacingOccurrences(of: "/", with: "_")
        let dbPath = cacheBase + "/" + sanitized
        try FileManager.default.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        
        // 5. Load IndexStoreLibrary via xcode-select -p
        let developerPath: String = {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
            proc.arguments = ["-p"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }()
        
        let devPath = developerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try the toolchain location first, then fall back to the SharedFrameworks location
        let toolchainLib = devPath + "/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        let sharedFrameworkLib = devPath + "/../SharedFrameworks/IndexStore.framework/Versions/A/IndexStore"
        let libPath = FileManager.default.fileExists(atPath: toolchainLib) ? toolchainLib : sharedFrameworkLib
        let library = try? IndexStoreLibrary(dylibPath: libPath)
        
        // 6. Initialise IndexStoreDB
        let db = try IndexStoreDB(
            storePath: storePath,
            databasePath: dbPath,
            library: library,
            waitUntilDoneInitializing: true,
            listenToUnitEvents: false
        )
        
        // 7. Store in actor
        await indexStore.setDatabase(db, workspacePath: workspacePath)
        
        // 8. Return success
        return CallTool.Result(
            content: [.text(text: "Index loaded: \(storePath)", annotations: nil, _meta: nil)]
        )
    } catch {
        return CallTool.Result(
            content: [.text(text: "Failed to load index: \(error)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
