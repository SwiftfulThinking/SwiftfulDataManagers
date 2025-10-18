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
    internal let configuration: DataManagerConfiguration
    public let logger: (any DataLogger)?

    // MARK: - Initialization

    /// Initialize the DocumentManagerAsync
    /// - Parameters:
    ///   - remote: Remote document service
    ///   - configuration: Manager configuration
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteDocumentService<T>,
        configuration: DataManagerConfiguration,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Get a document by ID from remote
    /// - Parameter id: The document ID
    /// - Returns: The document
    /// - Throws: Error if get fails
    open func getDocument(id: String) async throws -> T {
        logger?.trackEvent(event: Event.getStart(key: configuration.managerKey, documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.getSuccess(key: configuration.managerKey, documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.getFail(key: configuration.managerKey, documentId: id, error: error))
            throw error
        }
    }

    /// Save a complete document
    /// - Parameter document: The document to save
    /// - Throws: Error if save fails
    open func saveDocument(_ document: T) async throws {
        logger?.trackEvent(event: Event.saveStart(key: configuration.managerKey, documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(key: configuration.managerKey, documentId: document.id))
        } catch {
            logger?.trackEvent(event: Event.saveFail(key: configuration.managerKey, documentId: document.id, error: error))
            throw error
        }
    }

    /// Update document with a dictionary of fields
    /// - Parameters:
    ///   - id: The document ID
    ///   - data: Dictionary of fields to update
    /// - Throws: Error if update fails
    open func updateDocument(id: String, data: [String: any Sendable]) async throws {
        logger?.trackEvent(event: Event.updateStart(key: configuration.managerKey, documentId: id))

        do {
            try await remote.updateDocument(id: id, data: data)
            logger?.trackEvent(event: Event.updateSuccess(key: configuration.managerKey, documentId: id))
        } catch {
            logger?.trackEvent(event: Event.updateFail(key: configuration.managerKey, documentId: id, error: error))
            throw error
        }
    }

    /// Delete a document
    /// - Parameter id: The document ID
    /// - Throws: Error if deletion fails
    open func deleteDocument(id: String) async throws {
        logger?.trackEvent(event: Event.deleteStart(key: configuration.managerKey, documentId: id))

        do {
            try await remote.deleteDocument(id: id)
            logger?.trackEvent(event: Event.deleteSuccess(key: configuration.managerKey, documentId: id))
        } catch {
            logger?.trackEvent(event: Event.deleteFail(key: configuration.managerKey, documentId: id, error: error))
            throw error
        }
    }

    // MARK: - Events

    enum Event: DataLogEvent {
        case getStart(key: String, documentId: String)
        case getSuccess(key: String, documentId: String)
        case getFail(key: String, documentId: String, error: Error)
        case saveStart(key: String, documentId: String)
        case saveSuccess(key: String, documentId: String)
        case saveFail(key: String, documentId: String, error: Error)
        case updateStart(key: String, documentId: String)
        case updateSuccess(key: String, documentId: String)
        case updateFail(key: String, documentId: String, error: Error)
        case deleteStart(key: String, documentId: String)
        case deleteSuccess(key: String, documentId: String)
        case deleteFail(key: String, documentId: String, error: Error)

        var eventName: String {
            switch self {
            case .getStart(let key, _):                 return "\(key)_get_start"
            case .getSuccess(let key, _):               return "\(key)_get_success"
            case .getFail(let key, _, _):               return "\(key)_get_fail"
            case .saveStart(let key, _):                return "\(key)_save_start"
            case .saveSuccess(let key, _):              return "\(key)_save_success"
            case .saveFail(let key, _, _):              return "\(key)_save_fail"
            case .updateStart(let key, _):              return "\(key)_update_start"
            case .updateSuccess(let key, _):            return "\(key)_update_success"
            case .updateFail(let key, _, _):            return "\(key)_update_fail"
            case .deleteStart(let key, _):              return "\(key)_delete_start"
            case .deleteSuccess(let key, _):            return "\(key)_delete_success"
            case .deleteFail(let key, _, _):            return "\(key)_delete_fail"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .getStart(_, let documentId), .getSuccess(_, let documentId),
                 .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId):
                dict["document_id"] = documentId
            case .getFail(_, let documentId, let error), .saveFail(_, let documentId, let error),
                 .updateFail(_, let documentId, let error), .deleteFail(_, let documentId, let error):
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
