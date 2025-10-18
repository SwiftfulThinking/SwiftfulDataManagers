//
//  MockLocalCollectionPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of LocalCollectionPersistence for testing and previews.
public final class MockLocalCollectionPersistence<T: DataModelProtocol>: LocalCollectionPersistence, @unchecked Sendable {

    // MARK: - Properties

    private let managerKey: String
    private var cachedCollection: [T] = []
    private var cachedPendingWrites: [[String: any Sendable]] = []

    // MARK: - Initialization

    public init(managerKey: String, collection: [T] = []) {
        self.managerKey = managerKey
        self.cachedCollection = collection
    }

    // MARK: - LocalCollectionPersistence Implementation

    public func saveCollection(_ collection: [T]) throws {
        cachedCollection = collection
    }

    public func getCollection() throws -> [T] {
        return cachedCollection
    }

    public func saveDocument(_ document: T) throws {
        if let index = cachedCollection.firstIndex(where: { $0.id == document.id }) {
            cachedCollection[index] = document
        } else {
            cachedCollection.append(document)
        }
    }

    public func deleteDocument(id: String) throws {
        cachedCollection.removeAll(where: { $0.id == id })
    }

    public func savePendingWrites(_ writes: [[String: any Sendable]]) throws {
        cachedPendingWrites = writes
    }

    public func getPendingWrites() throws -> [[String: any Sendable]] {
        return cachedPendingWrites
    }

    public func clearPendingWrites() throws {
        cachedPendingWrites = []
    }
}
