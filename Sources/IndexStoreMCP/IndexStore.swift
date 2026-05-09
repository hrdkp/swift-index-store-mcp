import IndexStoreDB

actor IndexStore {
    private(set) var database: IndexStoreDB? = nil
    private(set) var loadedWorkspacePath: String? = nil

    /// Returns both fields together in a single actor hop, guaranteeing they
    /// are consistent with each other. Prefer this over reading `database` and
    /// `loadedWorkspacePath` separately to avoid TOCTOU races between awaits.
    var indexContext: (database: IndexStoreDB, workspacePath: String)? {
        guard let db = database, let path = loadedWorkspacePath else { return nil }
        return (database: db, workspacePath: path)
    }

    func setDatabase(_ db: IndexStoreDB, workspacePath: String) {
        self.database = db
        self.loadedWorkspacePath = workspacePath
    }
}
