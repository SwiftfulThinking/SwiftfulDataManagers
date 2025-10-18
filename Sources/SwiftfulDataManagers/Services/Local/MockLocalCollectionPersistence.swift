//
//  MockLocalCollectionPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of LocalCollectionPersistence for testing and previews.
public final class MockLocalCollectionPersistence<T: DMProtocol>: LocalCollectionPersistence, @unchecked Sendable {

    // MARK: - Properties

    private var collections: [String: [T]] = [:]
    private var pendingWrites: [String: [PendingWrite]] = [:]
    private let defaultCollection: [T]

    // MARK: - Initialization

    public init(collection: [T] = []) {
        self.defaultCollection = collection
        if !collection.isEmpty {
            // Store under a wildcard that will be returned for any key
            self.collections["*"] = collection
        }
    }

    // MARK: - LocalCollectionPersistence Implementation

    public func saveCollection(managerKey: String, _ collection: [T]) async throws {
        collections[managerKey] = collection
    }

    public func getCollection(managerKey: String) throws -> [T] {
        // Return specific key if it exists, otherwise return wildcard default
        return collections[managerKey] ?? collections["*"] ?? []
    }

    public func saveDocument(managerKey: String, _ document: T) throws {
        var collection = collections[managerKey] ?? []
        if let index = collection.firstIndex(where: { $0.id == document.id }) {
            collection[index] = document
        } else {
            collection.append(document)
        }
        collections[managerKey] = collection
    }

    public func deleteDocument(managerKey: String, id: String) throws {
        var collection = collections[managerKey] ?? []
        collection.removeAll(where: { $0.id == id })
        collections[managerKey] = collection
    }

    public func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws {
        pendingWrites[managerKey] = writes
    }

    public func getPendingWrites(managerKey: String) throws -> [PendingWrite] {
        return pendingWrites[managerKey] ?? []
    }

    public func clearPendingWrites(managerKey: String) throws {
        pendingWrites[managerKey] = []
    }
}
