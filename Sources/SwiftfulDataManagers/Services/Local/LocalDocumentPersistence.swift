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
/// struct FileManagerDocumentPersistence<T: DataModelProtocol>: LocalDocumentPersistence {
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
    associatedtype T: DataModelProtocol

    /// Save a document to local storage
    /// - Parameter document: The document to save (nil to clear)
    /// - Throws: Error if save fails
    func saveDocument(_ document: T?) throws

    /// Retrieve the cached document from local storage
    /// - Returns: The cached document, or nil if not found
    /// - Throws: Error if retrieval fails
    func getDocument() throws -> T?

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

    /// Save the document ID to local storage
    /// - Parameter id: The document ID (nil to clear)
    /// - Throws: Error if save fails
    func saveDocumentId(_ id: String?) throws

    /// Retrieve the document ID from local storage
    /// - Returns: The cached document ID, or nil if not found
    /// - Throws: Error if retrieval fails
    func getDocumentId() throws -> String?
}
