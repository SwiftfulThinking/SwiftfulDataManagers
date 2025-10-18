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
/// struct SwiftDataCollectionPersistence<T: DataModelProtocol>: LocalCollectionPersistence {
///     func saveCollection(_ collection: [T]) throws {
///         // Save to SwiftData
///     }
///
///     func getCollection() throws -> [T] {
///         // Load from SwiftData
///     }
/// }
/// ```
public protocol LocalCollectionPersistence<T>: Sendable {
    associatedtype T: DataModelProtocol

    /// Save the entire collection to local storage
    /// - Parameter collection: The collection to save
    /// - Throws: Error if save fails
    func saveCollection(_ collection: [T]) throws

    /// Retrieve the cached collection from local storage
    /// - Returns: The cached collection
    /// - Throws: Error if retrieval fails
    func getCollection() throws -> [T]

    /// Save a single document to local storage
    /// - Parameter document: The document to save
    /// - Throws: Error if save fails
    func saveDocument(_ document: T) throws

    /// Delete a single document from local storage
    /// - Parameter id: The document ID to delete
    /// - Throws: Error if delete fails
    func deleteDocument(id: String) throws

    /// Save pending writes to local storage
    /// - Parameter writes: Array of pending write operations
    /// - Throws: Error if save fails
    func savePendingWrites(_ writes: [[String: any Sendable]]) throws

    /// Retrieve pending writes from local storage
    /// - Returns: Array of pending write operations
    /// - Throws: Error if retrieval fails
    func getPendingWrites() throws -> [[String: any Sendable]]

    /// Clear all pending writes from local storage
    /// - Throws: Error if clear fails
    func clearPendingWrites() throws
}
