//
//  RemoteCollectionService.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Protocol defining remote collection operations.
///
/// Implement this protocol to provide backend-specific collection management
/// (e.g., Firebase, Supabase, custom REST API).
///
/// Example:
/// ```swift
/// struct FirebaseCollectionService<T: DataSyncModelProtocol>: RemoteCollectionService {
///     func getCollection() async throws -> [T] {
///         // Fetch from Firestore collection
///     }
///
///     func streamCollection() -> AsyncThrowingStream<[T], Error> {
///         // Listen to Firestore collection
///     }
/// }
/// ```
@MainActor
public protocol RemoteCollectionService<T>: Sendable {
    associatedtype T: DataSyncModelProtocol

    /// Fetch all documents in the collection
    /// - Returns: Array of all documents
    /// - Throws: Error if fetch fails
    func getCollection() async throws -> [T]

    /// Fetch a single document by ID
    /// - Parameter id: The document's unique identifier
    /// - Returns: The document model
    /// - Throws: Error if document not found or fetch fails
    func getDocument(id: String) async throws -> T

    /// Stream real-time updates for a document
    /// - Parameter id: The document's unique identifier
    /// - Returns: An async stream of document updates (nil if document is deleted)
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error>

    /// Create or update a document
    /// - Parameter model: The document model to save
    /// - Throws: Error if save fails
    func saveDocument(_ model: T) async throws

    /// Update document with a dictionary of fields
    /// - Parameters:
    ///   - id: The document's unique identifier
    ///   - data: Dictionary of fields to update
    /// - Throws: Error if update fails
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws

    /// Stream real-time updates for individual documents in the collection
    /// - Returns: Tuple of (updates stream, deletions stream)
    /// - Note: Updates stream yields individual document changes, deletions stream yields document IDs
    func streamCollectionUpdates() -> (
        updates: AsyncThrowingStream<T, Error>,
        deletions: AsyncThrowingStream<String, Error>
    )

    /// Delete a document
    /// - Parameter id: The document's unique identifier
    /// - Throws: Error if deletion fails
    func deleteDocument(id: String) async throws

    /// Query documents using QueryBuilder
    /// - Parameter query: QueryBuilder with filter conditions
    /// - Returns: Array of documents matching all query filters
    /// - Throws: Error if query fails
    func getDocuments(query: QueryBuilder) async throws -> [T]
}
