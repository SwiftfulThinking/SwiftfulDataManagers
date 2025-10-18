//
//  DocumentManagerAsync.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Asynchronous document manager with no listener or local persistence.
///
/// Provides async/await methods for document operations without caching or real-time updates.
///
/// Example:
/// ```swift
/// let manager = DocumentManagerAsync<Product>(
///     remote: FirebaseDocumentService(),
///     logger: myLogger
/// )
///
/// // Fetch document
/// let product = try await manager.fetchDocument(id: "product_123")
///
/// // Update document
/// try await manager.updateDocument(id: "product_123", data: ["price": 29.99])
/// ```
open class DocumentManagerAsync<T: DataModelProtocol> {

    // MARK: - Internal Properties

    internal let remote: any RemoteDocumentService<T>
    internal let logger: (any DataLogger)?

    // MARK: - Initialization

    /// Initialize the DocumentManagerAsync
    /// - Parameters:
    ///   - remote: Remote document service
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteDocumentService<T>,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Fetch a document by ID
    /// - Parameter id: The document ID
    /// - Returns: The document
    /// - Throws: Error if fetch fails
    open func fetchDocument(id: String) async throws -> T {
        logger?.trackEvent(event: Event.fetchStart(documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.fetchSuccess(documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.fetchFail(documentId: id, error: error))
            throw error
        }
    }

    /// Save a complete document
    /// - Parameter document: The document to save
    /// - Throws: Error if save fails
    open func saveDocument(_ document: T) async throws {
        logger?.trackEvent(event: Event.saveStart(documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(documentId: document.id))
        } catch {
            logger?.trackEvent(event: Event.saveFail(documentId: document.id, error: error))
            throw error
        }
    }

    /// Update document with a dictionary of fields
    /// - Parameters:
    ///   - id: The document ID
    ///   - data: Dictionary of fields to update
    /// - Throws: Error if update fails
    open func updateDocument(id: String, data: [String: any Sendable]) async throws {
        logger?.trackEvent(event: Event.updateStart(documentId: id))

        do {
            try await remote.updateDocument(id: id, data: data)
            logger?.trackEvent(event: Event.updateSuccess(documentId: id))
        } catch {
            logger?.trackEvent(event: Event.updateFail(documentId: id, error: error))
            throw error
        }
    }

    /// Update a single field
    /// - Parameters:
    ///   - id: The document ID
    ///   - field: Field name
    ///   - value: New value
    /// - Throws: Error if update fails
    open func updateDocumentField(id: String, field: String, value: any Sendable) async throws {
        try await updateDocument(id: id, data: [field: value])
    }

    /// Update multiple fields
    /// - Parameters:
    ///   - id: The document ID
    ///   - fields: Dictionary of fields to update
    /// - Throws: Error if update fails
    open func updateDocumentFields(id: String, fields: [String: any Sendable]) async throws {
        try await updateDocument(id: id, data: fields)
    }

    /// Delete a document
    /// - Parameter id: The document ID
    /// - Throws: Error if deletion fails
    open func deleteDocument(id: String) async throws {
        logger?.trackEvent(event: Event.deleteStart(documentId: id))

        do {
            try await remote.deleteDocument(id: id)
            logger?.trackEvent(event: Event.deleteSuccess(documentId: id))
        } catch {
            logger?.trackEvent(event: Event.deleteFail(documentId: id, error: error))
            throw error
        }
    }

    // MARK: - Events

    enum Event: DataLogEvent {
        case fetchStart(documentId: String)
        case fetchSuccess(documentId: String)
        case fetchFail(documentId: String, error: Error)
        case saveStart(documentId: String)
        case saveSuccess(documentId: String)
        case saveFail(documentId: String, error: Error)
        case updateStart(documentId: String)
        case updateSuccess(documentId: String)
        case updateFail(documentId: String, error: Error)
        case deleteStart(documentId: String)
        case deleteSuccess(documentId: String)
        case deleteFail(documentId: String, error: Error)

        var eventName: String {
            switch self {
            case .fetchStart:               return "DocManA_fetch_start"
            case .fetchSuccess:             return "DocManA_fetch_success"
            case .fetchFail:                return "DocManA_fetch_fail"
            case .saveStart:                return "DocManA_save_start"
            case .saveSuccess:              return "DocManA_save_success"
            case .saveFail:                 return "DocManA_save_fail"
            case .updateStart:              return "DocManA_update_start"
            case .updateSuccess:            return "DocManA_update_success"
            case .updateFail:               return "DocManA_update_fail"
            case .deleteStart:              return "DocManA_delete_start"
            case .deleteSuccess:            return "DocManA_delete_success"
            case .deleteFail:               return "DocManA_delete_fail"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .fetchStart(let documentId), .fetchSuccess(let documentId),
                 .saveStart(let documentId), .saveSuccess(let documentId),
                 .updateStart(let documentId), .updateSuccess(let documentId),
                 .deleteStart(let documentId), .deleteSuccess(let documentId):
                dict["document_id"] = documentId
            case .fetchFail(let documentId, let error), .saveFail(let documentId, let error),
                 .updateFail(let documentId, let error), .deleteFail(let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .fetchFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
