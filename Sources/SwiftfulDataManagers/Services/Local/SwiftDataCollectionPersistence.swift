//
//  SwiftDataCollectionPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import SwiftData

@MainActor
public final class SwiftDataCollectionPersistence<T: DMProtocol>: LocalCollectionPersistence {

    private let managerKey: String
    private let container: ModelContainer

    private var mainContext: ModelContext {
        container.mainContext
    }

    public init(managerKey: String) {
        self.managerKey = managerKey
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: DocumentEntity<T>.self)
    }

    public func getCollection(managerKey: String) throws -> [T] {
        let descriptor = FetchDescriptor<DocumentEntity<T>>()
        let entities = try mainContext.fetch(descriptor)
        return try entities.map { try $0.toDocument() }
    }

    /// Save entire collection (runs on background thread for better performance)
    /// Uses batch fetch optimization: deletes all and inserts new in one operation
    nonisolated public func saveCollection(managerKey: String, _ collection: [T]) async throws {
        // Create background context - this runs off the main actor
        let backgroundContext = ModelContext(container)

        // Delete all existing
        let descriptor = FetchDescriptor<DocumentEntity<T>>()
        let allEntities = (try? backgroundContext.fetch(descriptor)) ?? []
        for entity in allEntities {
            backgroundContext.delete(entity)
        }

        // Insert new collection
        for document in collection {
            let entity = try DocumentEntity.from(document)
            backgroundContext.insert(entity)
        }

        // Single save for all operations
        try backgroundContext.save()
    }

    public func saveDocument(managerKey: String, _ document: T) throws {
        // Check if document already exists
        let descriptor = FetchDescriptor<DocumentEntity<T>>(
            predicate: #Predicate { $0.id == document.id }
        )
        if let existing = try? mainContext.fetch(descriptor).first {
            // Update existing entity
            try existing.update(from: document)
        } else {
            // Insert new entity
            let entity = try DocumentEntity.from(document)
            mainContext.insert(entity)
        }
        try mainContext.save()
    }

    public func deleteDocument(managerKey: String, id: String) throws {
        let descriptor = FetchDescriptor<DocumentEntity<T>>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = try? mainContext.fetch(descriptor).first {
            mainContext.delete(entity)
            try mainContext.save()
        }
    }

    // MARK: - Pending Writes Persistence

    private func pendingWritesFileURL(managerKey: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("CollectionManager_PendingWrites_\(managerKey).json")
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
