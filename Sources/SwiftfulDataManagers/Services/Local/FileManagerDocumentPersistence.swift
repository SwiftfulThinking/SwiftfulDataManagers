//
//  FileManagerDocumentPersistence.swift
//  SwiftfulDataManagers
//
//  Production-ready local persistence using FileManager
//

import Foundation

public struct FileManagerDocumentPersistence<T: DataSyncModelProtocol>: LocalDocumentPersistence {

    public init() { }

    public func saveDocument(managerKey: String, _ document: T?) throws {
        let key = "document_\(managerKey)"
        try FileManager.saveDocument(key: key, value: document)
    }

    public func getDocument(managerKey: String) throws -> T? {
        let key = "document_\(managerKey)"
        return try? FileManager.getDocument(key: key)
    }

    public func saveDocumentId(managerKey: String, _ id: String?) throws {
        let key = "documentId_\(managerKey)"
        if let id = id {
            UserDefaults.standard.set(id, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    public func getDocumentId(managerKey: String) throws -> String? {
        let key = "documentId_\(managerKey)"
        let id = UserDefaults.standard.string(forKey: key)
        return id?.isEmpty == true ? nil : id
    }

    // MARK: - Pending Writes Persistence

    private func pendingWritesFileURL(managerKey: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("DocumentManager_PendingWrites_\(managerKey).json")
    }

    public func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws {
        let fileURL = pendingWritesFileURL(managerKey: managerKey)
        let dictionaries = writes.map { $0.toDictionary() }
        let data = try JSONSerialization.data(withJSONObject: dictionaries)
        try data.write(to: fileURL)
    }

    public func getPendingWrites(managerKey: String) throws -> [PendingWrite] {
        let fileURL = pendingWritesFileURL(managerKey: managerKey)
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        guard let dictionaries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return dictionaries.compactMap { PendingWrite.fromDictionary($0) }
    }

    public func clearPendingWrites(managerKey: String) throws {
        let fileURL = pendingWritesFileURL(managerKey: managerKey)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
