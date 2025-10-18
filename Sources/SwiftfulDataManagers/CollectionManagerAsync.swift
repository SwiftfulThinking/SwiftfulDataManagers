//
//  CollectionManagerAsync.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Asynchronous collection manager with no listener or local persistence.
///
/// Provides async/await methods for collection operations without caching or real-time updates.
///
/// Example:
/// ```swift
/// let manager = CollectionManagerAsync<Product>(
///     remote: FirebaseCollectionService(),
///     logger: myLogger
/// )
///
/// // Fetch collection
/// let products = try await manager.fetchCollection()
///
/// // Update document in collection
/// try await manager.updateDocument(id: "product_123", data: ["price": 29.99])
/// ```
open class CollectionManagerAsync<T: DataModelProtocol> {

    // MARK: - Internal Properties

    internal let remote: any RemoteCollectionService<T>
    internal let logger: (any DataLogger)?

    // MARK: - Initialization

    /// Initialize the CollectionManagerAsync
    /// - Parameters:
    ///   - remote: Remote collection service
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteCollectionService<T>,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Get the entire collection from remote
    /// - Returns: Array of all documents
    /// - Throws: Error if get fails
    open func getCollection() async throws -> [T] {
        logger?.trackEvent(event: Event.getCollectionStart)

        do {
            let collection = try await remote.getCollection()
            logger?.trackEvent(event: Event.getCollectionSuccess(count: collection.count))
            return collection
        } catch {
            logger?.trackEvent(event: Event.getCollectionFail(error: error))
            throw error
        }
    }

    /// Get a single document by ID from remote
    /// - Parameter id: The document ID
    /// - Returns: The document
    /// - Throws: Error if get fails
    open func getDocument(id: String) async throws -> T {
        logger?.trackEvent(event: Event.getDocumentStart(documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.getDocumentSuccess(documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.getDocumentFail(documentId: id, error: error))
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
        case getCollectionStart
        case getCollectionSuccess(count: Int)
        case getCollectionFail(error: Error)
        case getDocumentStart(documentId: String)
        case getDocumentSuccess(documentId: String)
        case getDocumentFail(documentId: String, error: Error)
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
            case .getCollectionStart:       return "ColManA_get_collection_start"
            case .getCollectionSuccess:     return "ColManA_get_collection_success"
            case .getCollectionFail:        return "ColManA_get_collection_fail"
            case .getDocumentStart:         return "ColManA_get_document_start"
            case .getDocumentSuccess:       return "ColManA_get_document_success"
            case .getDocumentFail:          return "ColManA_get_document_fail"
            case .saveStart:                return "ColManA_save_start"
            case .saveSuccess:              return "ColManA_save_success"
            case .saveFail:                 return "ColManA_save_fail"
            case .updateStart:              return "ColManA_update_start"
            case .updateSuccess:            return "ColManA_update_success"
            case .updateFail:               return "ColManA_update_fail"
            case .deleteStart:              return "ColManA_delete_start"
            case .deleteSuccess:            return "ColManA_delete_success"
            case .deleteFail:               return "ColManA_delete_fail"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .getCollectionSuccess(let count):
                dict["count"] = count
            case .getCollectionFail(let error):
                dict.merge(error.eventParameters)
            case .getDocumentStart(let documentId), .getDocumentSuccess(let documentId),
                 .saveStart(let documentId), .saveSuccess(let documentId),
                 .updateStart(let documentId), .updateSuccess(let documentId),
                 .deleteStart(let documentId), .deleteSuccess(let documentId):
                dict["document_id"] = documentId
            case .getDocumentFail(let documentId, let error), .saveFail(let documentId, let error),
                 .updateFail(let documentId, let error), .deleteFail(let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            default:
                break
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .getCollectionFail, .getDocumentFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
