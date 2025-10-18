//
//  MockRemoteCollectionService.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of RemoteCollectionService for testing and previews.
@MainActor
public final class MockRemoteCollectionService<T: DataModelProtocol>: RemoteCollectionService, @unchecked Sendable {

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
