import IndexStoreDB

actor IndexStore {
    
    enum ReserveLoadingResult: Equatable {
        case reserved
        case loadInProgress
        case alreadyLoaded(samePath: Bool)
    }
    
    private var isLoading = false
    private(set) var database: IndexStoreDB? = nil
    private var loadedWorkspacePath: String? = nil
    
    /// Returns both fields together in a single actor hop, guaranteeing they
    /// are consistent with each other. Prefer this over reading `database` and
    /// `loadedWorkspacePath` separately to avoid TOCTOU races between awaits.
    var indexContext: (database: IndexStoreDB, workspacePath: String)? {
        guard let db = database, let path = loadedWorkspacePath else { return nil }
        return (database: db, workspacePath: path)
    }
    
    /// Atomically reserves the right to load. Must be called before crossing
    /// any await boundaries in the load path. Always pair with `loadEnded`
    /// (via defer) and call `setDatabase` on success.
    func reserveLoading(workspacePath: String) -> ReserveLoadingResult {
        if let existing = loadedWorkspacePath {
            return .alreadyLoaded(samePath: existing == workspacePath)
        }
        if isLoading {
            return .loadInProgress
        }
        isLoading = true
        return .reserved
    }
    
    func setDatabase(_ db: IndexStoreDB, workspacePath: String) {
        self.database = db
        self.loadedWorkspacePath = workspacePath
    }
    
    func loadEnded() {
        self.isLoading = false
    }
}
