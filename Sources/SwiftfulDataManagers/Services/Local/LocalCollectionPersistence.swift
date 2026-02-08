//
//  LocalCollectionPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Protocol defining local collection persistence operations.
///
/// Implement this protocol to provide local caching for a collection
/// (e.g., SwiftData, CoreData, Realm).
///
/// Example:
/// ```swift
/// struct SwiftDataCollectionPersistence<T: DataSyncModelProtocol>: LocalCollectionPersistence {
///     func saveCollection(_ collection: [T]) throws {
///         // Save to SwiftData
///     }
///
///     func getCollection() throws -> [T] {
///         // Load from SwiftData
///     }
/// }
/// ```
@MainActor
public protocol LocalCollectionPersistence<T>: Sendable {
    associatedtype T: DataSyncModelProtocol

    /// Save the entire collection to local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - collection: The collection to save
    /// - Throws: Error if save fails
    func saveCollection(managerKey: String, _ collection: [T]) async throws

    /// Retrieve the cached collection from local storage
    /// - Parameter managerKey: The key identifying this manager
    /// - Returns: The cached collection
    /// - Throws: Error if retrieval fails
    func getCollection(managerKey: String) throws -> [T]

    /// Save a single document to local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - document: The document to save
    /// - Throws: Error if save fails
    func saveDocument(managerKey: String, _ document: T) throws

    /// Delete a single document from local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - id: The document ID to delete
    /// - Throws: Error if delete fails
    func deleteDocument(managerKey: String, id: String) throws

    /// Save pending writes to local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - writes: Array of pending write operations
    /// - Throws: Error if save fails
    func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws

    /// Retrieve pending writes from local storage
    /// - Parameter managerKey: The key identifying this manager
    /// - Returns: Array of pending write operations
    /// - Throws: Error if retrieval fails
    func getPendingWrites(managerKey: String) throws -> [PendingWrite]

    /// Clear all pending writes from local storage
    /// - Parameter managerKey: The key identifying this manager
    /// - Throws: Error if clear fails
    func clearPendingWrites(managerKey: String) throws
}
