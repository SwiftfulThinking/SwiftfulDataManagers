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

    /// Get a document by ID from remote
    /// - Parameter id: The document ID
    /// - Returns: The document
    /// - Throws: Error if get fails
    open func getDocument(id: String) async throws -> T {
        logger?.trackEvent(event: Event.getStart(documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.getSuccess(documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.getFail(documentId: id, error: error))
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
        case getStart(documentId: String)
        case getSuccess(documentId: String)
        case getFail(documentId: String, error: Error)
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
            case .getStart:                 return "DocManA_get_start"
            case .getSuccess:               return "DocManA_get_success"
            case .getFail:                  return "DocManA_get_fail"
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
            case .getStart(let documentId), .getSuccess(let documentId),
                 .saveStart(let documentId), .saveSuccess(let documentId),
                 .updateStart(let documentId), .updateSuccess(let documentId),
                 .deleteStart(let documentId), .deleteSuccess(let documentId):
                dict["document_id"] = documentId
            case .getFail(let documentId, let error), .saveFail(let documentId, let error),
                 .updateFail(let documentId, let error), .deleteFail(let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .getFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
