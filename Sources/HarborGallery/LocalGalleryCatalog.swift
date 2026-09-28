import Foundation

enum LocalGalleryCatalog {
    private static let key = "harborGallery.notebookIDs.v1"

    static var notebookIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func add(_ notebookID: String) {
        var ids = notebookIDs
        ids.insert(notebookID)
        save(ids)
    }

    static func add<S: Sequence>(contentsOf notebookIDs: S) where S.Element == String {
        var ids = self.notebookIDs
        ids.formUnion(notebookIDs)
        save(ids)
    }

    static func remove(_ notebookID: String) {
        var ids = notebookIDs
        ids.remove(notebookID)
        save(ids)
    }

    static func retainOnly(_ existingNotebookIDs: Set<String>) {
        save(notebookIDs.intersection(existingNotebookIDs))
    }

    private static func save(_ notebookIDs: Set<String>) {
        UserDefaults.standard.set(Array(notebookIDs).sorted(), forKey: key)
    }
}
