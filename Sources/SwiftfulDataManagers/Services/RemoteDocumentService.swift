//
//  RemoteDocumentService.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Protocol defining remote document operations.
///
/// Implement this protocol to provide backend-specific document management
/// (e.g., Firebase, Supabase, custom REST API).
///
/// Example:
/// ```swift
/// struct FirebaseDocumentService<T: DataModelProtocol>: RemoteDocumentService {
///     func getDocument(id: String) async throws -> T {
///         // Fetch from Firestore
///     }
///
///     func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> {
///         // Listen to Firestore document
///     }
/// }
/// ```
@MainActor
public protocol RemoteDocumentService<T>: Sendable {
    associatedtype T: DataModelProtocol

    /// Fetch a document by ID
    /// - Parameter id: The document's unique identifier
    /// - Returns: The document model
    /// - Throws: Error if document not found or fetch fails
    func getDocument(id: String) async throws -> T

    /// Create or update a document
    /// - Parameter model: The document model to save
    /// - Throws: Error if save fails
    func saveDocument(_ model: T) async throws

    /// Update document with a dictionary of fields
    /// - Parameters:
    ///   - id: The document's unique identifier
    ///   - data: Dictionary of fields to update
    /// - Throws: Error if update fails
    func updateDocument(id: String, data: [String: any Sendable]) async throws

    /// Update a single document field
    /// - Parameters:
    ///   - id: The document's unique identifier
    ///   - field: The field name to update
    ///   - value: The new value
    /// - Throws: Error if update fails
    func updateDocumentField(id: String, field: String, value: any Sendable) async throws

    /// Update multiple document fields
    /// - Parameters:
    ///   - id: The document's unique identifier
    ///   - fields: Dictionary of field names to values
    /// - Throws: Error if update fails
    func updateDocumentFields(id: String, fields: [String: any Sendable]) async throws

    /// Stream real-time updates for a document
    /// - Parameter id: The document's unique identifier
    /// - Returns: An async stream of document updates (nil if document is deleted)
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error>

    /// Delete a document
    /// - Parameter id: The document's unique identifier
    /// - Throws: Error if deletion fails
    func deleteDocument(id: String) async throws
}
