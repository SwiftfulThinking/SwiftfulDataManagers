//
//  FileManagerDocumentPersistence.swift
//  SwiftfulDataManagers
//
//  Production-ready local persistence using FileManager
//

import Foundation

public struct FileManagerDocumentPersistence<T: DataModelProtocol>: LocalDocumentPersistence {

    private let managerKey: String

    public init(managerKey: String) {
        self.managerKey = managerKey
    }

    public func saveDocument(_ document: T?) throws {
        let key = "document_\(managerKey)"
        try FileManager.saveDocument(key: key, value: document)
    }

    public func getDocument() throws -> T? {
        let key = "document_\(managerKey)"
        return try? FileManager.getDocument(key: key)
    }

    public func saveDocumentId(_ id: String?) throws {
        let key = "documentId_\(managerKey)"
        if let id = id {
            UserDefaults.standard.set(id, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    public func getDocumentId() throws -> String? {
        let key = "documentId_\(managerKey)"
        let id = UserDefaults.standard.string(forKey: key)
        return id?.isEmpty == true ? nil : id
    }

    // MARK: - Pending Writes Persistence

    private func pendingWritesFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("DocumentManager_PendingWrites_\(managerKey).json")
    }

    public func savePendingWrites(_ writes: [[String: any Sendable]]) throws {
        let fileURL = pendingWritesFileURL()
        let data = try JSONSerialization.data(withJSONObject: writes)
        try data.write(to: fileURL)
    }

    public func getPendingWrites() throws -> [[String: any Sendable]] {
        let fileURL = pendingWritesFileURL()
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: any Sendable]]) ?? []
    }

    public func clearPendingWrites() throws {
        let fileURL = pendingWritesFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
