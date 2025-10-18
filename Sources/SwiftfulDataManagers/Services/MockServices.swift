//
//  MockServices.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of RemoteDocumentService for testing and previews.
@MainActor
public final class MockDocumentService<T: DataModelProtocol>: RemoteDocumentService, @unchecked Sendable {

    // MARK: - Properties

    private var currentDocument: T?
    private var continuation: AsyncThrowingStream<T?, Error>.Continuation?

    // MARK: - Initialization

    public nonisolated init(document: T? = nil) {
        self.currentDocument = document
    }

    // MARK: - RemoteDocumentService Implementation

    public func getDocument(id: String) async throws -> T {
        try await Task.sleep(for: .seconds(0.5))

        guard let currentDocument, currentDocument.id == id else {
            throw MockError.documentNotFound
        }

        return currentDocument
    }

    public func saveDocument(_ model: T) async throws {
        try await Task.sleep(for: .seconds(0.5))
        currentDocument = model
        continuation?.yield(model)
    }

    public func updateDocument(id: String, data: [String: any Sendable]) async throws {
        try await Task.sleep(for: .seconds(0.5))

        guard currentDocument?.id == id else {
            throw MockError.documentNotFound
        }

        continuation?.yield(currentDocument)
    }

    public func updateDocumentField(id: String, field: String, value: any Sendable) async throws {
        try await updateDocument(id: id, data: [field: value])
    }

    public func updateDocumentFields(id: String, fields: [String: any Sendable]) async throws {
        try await updateDocument(id: id, data: fields)
    }

    public nonisolated func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                self.continuation = continuation
                continuation.yield(self.currentDocument)

                continuation.onTermination = { @Sendable _ in
                    Task { @MainActor in
                        self.continuation = nil
                    }
                }
            }
        }
    }

    public func deleteDocument(id: String) async throws {
        try await Task.sleep(for: .seconds(0.5))

        guard currentDocument?.id == id else {
            throw MockError.documentNotFound
        }

        currentDocument = nil
        continuation?.yield(nil)
    }

    // MARK: - Mock Error

    enum MockError: LocalizedError {
        case documentNotFound

        var errorDescription: String? {
            switch self {
            case .documentNotFound:
                return "Document not found"
            }
        }
    }
}

/// Mock implementation of RemoteCollectionService for testing and previews.
@MainActor
public final class MockCollectionService<T: DataModelProtocol>: RemoteCollectionService, @unchecked Sendable {

    // MARK: - Properties

    private var currentCollection: [T] = []
    private var continuation: AsyncThrowingStream<[T], Error>.Continuation?

    // MARK: - Initialization

    public nonisolated init(collection: [T] = []) {
        self.currentCollection = collection
    }

    // MARK: - RemoteCollectionService Implementation

    public func getCollection() async throws -> [T] {
        try await Task.sleep(for: .seconds(0.5))
        return currentCollection
    }

    public func getDocument(id: String) async throws -> T {
        try await Task.sleep(for: .seconds(0.5))

        guard let document = currentCollection.first(where: { $0.id == id }) else {
            throw MockError.documentNotFound
        }

        return document
    }

    public func saveDocument(_ model: T) async throws {
        try await Task.sleep(for: .seconds(0.5))

        if let index = currentCollection.firstIndex(where: { $0.id == model.id }) {
            currentCollection[index] = model
        } else {
            currentCollection.append(model)
        }

        continuation?.yield(currentCollection)
    }

    public func updateDocument(id: String, data: [String: any Sendable]) async throws {
        try await Task.sleep(for: .seconds(0.5))

        guard currentCollection.contains(where: { $0.id == id }) else {
            throw MockError.documentNotFound
        }

        continuation?.yield(currentCollection)
    }

    public func updateDocumentField(id: String, field: String, value: any Sendable) async throws {
        try await updateDocument(id: id, data: [field: value])
    }

    public func updateDocumentFields(id: String, fields: [String: any Sendable]) async throws {
        try await updateDocument(id: id, data: fields)
    }

    public nonisolated func streamCollection() -> AsyncThrowingStream<[T], Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                self.continuation = continuation
                continuation.yield(self.currentCollection)

                continuation.onTermination = { @Sendable _ in
                    Task { @MainActor in
                        self.continuation = nil
                    }
                }
            }
        }
    }

    public func deleteDocument(id: String) async throws {
        try await Task.sleep(for: .seconds(0.5))

        guard let index = currentCollection.firstIndex(where: { $0.id == id }) else {
            throw MockError.documentNotFound
        }

        currentCollection.remove(at: index)
        continuation?.yield(currentCollection)
    }

    // MARK: - Mock Error

    enum MockError: LocalizedError {
        case documentNotFound

        var errorDescription: String? {
            switch self {
            case .documentNotFound:
                return "Document not found"
            }
        }
    }
}

/// Mock implementation of LocalDocumentPersistence for testing and previews.
public final class MockDocumentPersistence<T: DataModelProtocol>: LocalDocumentPersistence, @unchecked Sendable {

    // MARK: - Properties

    private var cachedDocument: T?
    private var cachedDocumentId: String?
    private var cachedPendingWrites: [[String: any Sendable]] = []

    // MARK: - Initialization

    public init(document: T? = nil) {
        self.cachedDocument = document
        self.cachedDocumentId = document?.id
    }

    // MARK: - LocalDocumentPersistence Implementation

    public func saveDocument(_ document: T?) throws {
        cachedDocument = document
    }

    public func getDocument() throws -> T? {
        return cachedDocument
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

    public func saveDocumentId(_ id: String?) throws {
        cachedDocumentId = id
    }

    public func getDocumentId() throws -> String? {
        return cachedDocumentId
    }
}

/// Mock implementation of LocalCollectionPersistence for testing and previews.
public final class MockCollectionPersistence<T: DataModelProtocol>: LocalCollectionPersistence, @unchecked Sendable {

    // MARK: - Properties

    private var cachedCollection: [T] = []
    private var cachedPendingWrites: [[String: any Sendable]] = []

    // MARK: - Initialization

    public init(collection: [T] = []) {
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
