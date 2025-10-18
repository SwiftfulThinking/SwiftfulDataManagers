//
//  LocalDocumentPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Protocol defining local document persistence operations.
///
/// Implement this protocol to provide local caching for a single document
/// (e.g., FileManager, UserDefaults, CoreData).
///
/// Example:
/// ```swift
/// struct FileManagerDocumentPersistence<T: DMProtocol>: LocalDocumentPersistence {
///     func saveDocument(_ document: T?) throws {
///         // Save to FileManager
///     }
///
///     func getDocument() throws -> T? {
///         // Load from FileManager
///     }
/// }
/// ```
@MainActor
public protocol LocalDocumentPersistence<T>: Sendable {
    associatedtype T: DMProtocol

    /// Save a document to local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - document: The document to save (nil to clear)
    /// - Throws: Error if save fails
    func saveDocument(managerKey: String, _ document: T?) throws

    /// Retrieve the cached document from local storage
    /// - Parameter managerKey: The key identifying this manager
    /// - Returns: The cached document, or nil if not found
    /// - Throws: Error if retrieval fails
    func getDocument(managerKey: String) throws -> T?

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

    /// Save the document ID to local storage
    /// - Parameters:
    ///   - managerKey: The key identifying this manager
    ///   - id: The document ID (nil to clear)
    /// - Throws: Error if save fails
    func saveDocumentId(managerKey: String, _ id: String?) throws

    /// Retrieve the document ID from local storage
    /// - Parameter managerKey: The key identifying this manager
    /// - Returns: The cached document ID, or nil if not found
    /// - Throws: Error if retrieval fails
    func getDocumentId(managerKey: String) throws -> String?
}
