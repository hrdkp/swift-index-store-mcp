import IndexStoreDB

actor IndexStore {
    var database: IndexStoreDB? = nil
    var loadedWorkspacePath: String? = nil
    
    func setDatabase(_ db: IndexStoreDB, workspacePath: String) {
        self.database = db
        self.loadedWorkspacePath = workspacePath
    }
}
