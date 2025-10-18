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
    internal let configuration: DataManagerConfiguration
    public let logger: (any DataLogger)?

    // MARK: - Initialization

    /// Initialize the CollectionManagerAsync
    /// - Parameters:
    ///   - remote: Remote collection service
    ///   - configuration: Manager configuration
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteCollectionService<T>,
        configuration: DataManagerConfiguration,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Get the entire collection from remote
    /// - Returns: Array of all documents
    /// - Throws: Error if get fails
    open func getCollection() async throws -> [T] {
        logger?.trackEvent(event: Event.getCollectionStart(key: configuration.managerKey))

        do {
            let collection = try await remote.getCollection()
            logger?.trackEvent(event: Event.getCollectionSuccess(key: configuration.managerKey, count: collection.count))
            return collection
        } catch {
            logger?.trackEvent(event: Event.getCollectionFail(key: configuration.managerKey, error: error))
            throw error
        }
    }

    /// Get a single document by ID from remote
    /// - Parameter id: The document ID
    /// - Returns: The document
    /// - Throws: Error if get fails
    open func getDocument(id: String) async throws -> T {
        logger?.trackEvent(event: Event.getDocumentStart(key: configuration.managerKey, documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.getDocumentSuccess(key: configuration.managerKey, documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.getDocumentFail(key: configuration.managerKey, documentId: id, error: error))
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
    open func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws {
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

    /// Query documents based on field-value filters
    /// - Parameter filters: Dictionary of field names to values for exact match queries
    /// - Returns: Array of documents matching all filters from remote query
    /// - Throws: Error if query fails
    open func getDocuments(where filters: [String: any DMCodableSendable]) async throws -> [T] {
        logger?.trackEvent(event: Event.getDocumentsQueryStart(key: configuration.managerKey, filterCount: filters.count))

        do {
            let documents = try await remote.getDocuments(where: filters)
            logger?.trackEvent(event: Event.getDocumentsQuerySuccess(key: configuration.managerKey, count: documents.count, filterCount: filters.count))
            return documents
        } catch {
            logger?.trackEvent(event: Event.getDocumentsQueryFail(key: configuration.managerKey, filterCount: filters.count, error: error))
            throw error
        }
    }

    // MARK: - Events

    enum Event: DataLogEvent {
        case getCollectionStart(key: String)
        case getCollectionSuccess(key: String, count: Int)
        case getCollectionFail(key: String, error: Error)
        case getDocumentStart(key: String, documentId: String)
        case getDocumentSuccess(key: String, documentId: String)
        case getDocumentFail(key: String, documentId: String, error: Error)
        case getDocumentsQueryStart(key: String, filterCount: Int)
        case getDocumentsQuerySuccess(key: String, count: Int, filterCount: Int)
        case getDocumentsQueryFail(key: String, filterCount: Int, error: Error)
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
            case .getCollectionStart(let key):          return "\(key)_getCollection_start"
            case .getCollectionSuccess(let key, _):     return "\(key)_getCollection_success"
            case .getCollectionFail(let key, _):        return "\(key)_getCollection_fail"
            case .getDocumentStart(let key, _):         return "\(key)_getDocument_start"
            case .getDocumentSuccess(let key, _):       return "\(key)_getDocument_success"
            case .getDocumentFail(let key, _, _):       return "\(key)_getDocument_fail"
            case .getDocumentsQueryStart(let key, _):       return "\(key)_getDocumentsQuery_start"
            case .getDocumentsQuerySuccess(let key, _, _):  return "\(key)_getDocumentsQuery_success"
            case .getDocumentsQueryFail(let key, _, _):     return "\(key)_getDocumentsQuery_fail"
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
            case .getCollectionSuccess(_, let count):
                dict["count"] = count
            case .getCollectionFail(_, let error):
                dict.merge(error.eventParameters)
            case .getDocumentsQueryStart(_, let filterCount):
                dict["filter_count"] = filterCount
            case .getDocumentsQuerySuccess(_, let count, let filterCount):
                dict["count"] = count
                dict["filter_count"] = filterCount
            case .getDocumentsQueryFail(_, let filterCount, let error):
                dict["filter_count"] = filterCount
                dict.merge(error.eventParameters)
            case .getDocumentStart(_, let documentId), .getDocumentSuccess(_, let documentId),
                 .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId):
                dict["document_id"] = documentId
            case .getDocumentFail(_, let documentId, let error), .saveFail(_, let documentId, let error),
                 .updateFail(_, let documentId, let error), .deleteFail(_, let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            default:
                break
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .getCollectionFail, .getDocumentFail, .getDocumentsQueryFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
