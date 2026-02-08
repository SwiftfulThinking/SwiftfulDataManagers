//
//  CollectionSyncEngine.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno.
//

import Foundation
import Observation

/// Real-time collection sync engine with optional local persistence.
///
/// Manages a collection of documents with streaming updates, optional SwiftData caching,
/// and pending writes queue. Designed for composition (not subclassing).
///
/// Uses hybrid sync: bulk loads all documents on `startListening()`, then streams individual changes.
///
/// Example:
/// ```swift
/// let engine = CollectionSyncEngine<Product>(
///     remote: FirebaseRemoteCollectionService(collectionPath: { "products" }),
///     managerKey: "products",
///     logger: logManager
/// )
///
/// // Start real-time sync (bulk load + stream changes)
/// await engine.startListening()
///
/// // Access current collection (Observable — SwiftUI auto-updates)
/// for product in engine.currentCollection {
///     print(product.name)
/// }
///
/// // Save a document
/// try await engine.saveDocument(newProduct)
///
/// // Stop listening
/// engine.stopListening()
/// ```
@MainActor
@Observable
public final class CollectionSyncEngine<T: DataSyncModelProtocol> {

    // MARK: - Public Properties

    /// The current collection. Observable — SwiftUI views reading this will auto-update.
    public private(set) var currentCollection: [T] = []

    /// The logger instance, accessible for domain-specific logging in consuming code.
    public let logger: (any DataSyncLogger)?

    // MARK: - Internal Properties

    internal let remote: any RemoteCollectionService<T>
    internal let local: (any LocalCollectionPersistence<T>)?
    internal let managerKey: String
    internal let enableLocalPersistence: Bool

    // MARK: - Private Properties

    private var updatesListenerTask: Task<Void, Never>?
    private var deletionsListenerTask: Task<Void, Never>?
    private var pendingWrites: [PendingWrite] = []
    private var listenerFailedToAttach: Bool = false
    private var listenerRetryCount: Int = 0
    private var listenerRetryTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the CollectionSyncEngine.
    /// - Parameters:
    ///   - remote: The remote collection service (e.g., FirebaseRemoteCollectionService)
    ///   - managerKey: Unique key for local persistence paths and analytics event prefixes (e.g., "products", "watchlist")
    ///   - enableLocalPersistence: Whether to persist the collection locally via SwiftData and enable pending writes. Default `true`.
    ///   - logger: Optional logger for analytics events.
    public init(
        remote: any RemoteCollectionService<T>,
        managerKey: String,
        enableLocalPersistence: Bool = true,
        logger: (any DataSyncLogger)? = nil
    ) {
        self.remote = remote
        self.managerKey = managerKey
        self.enableLocalPersistence = enableLocalPersistence
        self.logger = logger

        if enableLocalPersistence {
            let persistence = SwiftDataCollectionPersistence<T>(managerKey: managerKey)
            self.local = persistence

            // Load cached collection from local storage
            self.currentCollection = (try? persistence.getCollection(managerKey: managerKey)) ?? []

            // Load pending writes
            self.pendingWrites = (try? persistence.getPendingWrites(managerKey: managerKey)) ?? []
        } else {
            self.local = nil
        }
    }

    // MARK: - Lifecycle

    /// Start listening for real-time collection updates.
    ///
    /// This will:
    /// 1. Sync any pending writes
    /// 2. Bulk load the entire collection from remote
    /// 3. Start streaming individual document changes (adds, updates, deletions)
    public func startListening() async {
        logger?.trackEvent(event: Event.listenerStart(key: managerKey))

        // Sync pending writes if enabled and available
        if enableLocalPersistence && !pendingWrites.isEmpty {
            await syncPendingWrites()
        }

        // Hybrid sync: Bulk load all documents, then stream changes
        await bulkLoadCollection()
        startListener()
    }

    /// Stop listening for real-time updates.
    ///
    /// - Parameter clearCaches: If true (default), clears `currentCollection`, pending writes,
    ///   and all local persistence. If false, only cancels the listeners.
    public func stopListening(clearCaches: Bool = true) {
        logger?.trackEvent(event: Event.listenerStopped(key: managerKey))
        stopListener()

        if clearCaches {
            // Clear memory
            currentCollection = []
            pendingWrites = []

            // Clear local persistence
            if enableLocalPersistence {
                Task {
                    try? await local?.saveCollection(managerKey: managerKey, [])
                }
                try? local?.savePendingWrites(managerKey: managerKey, [])
            }

            logger?.trackEvent(event: Event.cachesCleared(key: managerKey))
        }
    }

    // MARK: - Read: Collection

    /// Get the entire collection synchronously from cache.
    ///
    /// Returns empty if `startListening()` has not been called and no local persistence is available.
    /// - Returns: Array of all documents in the collection.
    public func getCollection() -> [T] {
        return currentCollection
    }

    /// Get collection asynchronously.
    /// - Parameter behavior: `.cachedOrFetch` (default) returns cached if available, `.alwaysFetch` always fetches from remote.
    /// - Returns: Array of all documents.
    /// - Throws: Error if fetch fails.
    public func getCollectionAsync(behavior: FetchBehavior = .cachedOrFetch) async throws -> [T] {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        // Return cached if available
        if behavior == .cachedOrFetch, !currentCollection.isEmpty {
            return currentCollection
        }

        // Fetch from remote
        logger?.trackEvent(event: Event.getCollectionStart(key: managerKey))

        do {
            let collection = try await remote.getCollection()
            logger?.trackEvent(event: Event.getCollectionSuccess(key: managerKey, count: collection.count))
            return collection
        } catch {
            logger?.trackEvent(event: Event.getCollectionFail(key: managerKey, error: error))
            throw error
        }
    }

    // MARK: - Read: Single Document

    /// Get a single document by ID synchronously from cache.
    ///
    /// Returns nil if `startListening()` has not been called and no local persistence is available.
    /// - Parameter id: The document ID.
    /// - Returns: The document if found, nil otherwise.
    public func getDocument(id: String) -> T? {
        return currentCollection.first { $0.id == id }
    }

    /// Get document asynchronously.
    /// - Parameters:
    ///   - id: The document ID to fetch.
    ///   - behavior: `.cachedOrFetch` (default) returns cached if available, `.alwaysFetch` always fetches from remote.
    /// - Returns: The document.
    /// - Throws: Error if fetch fails.
    public func getDocumentAsync(id: String, behavior: FetchBehavior = .cachedOrFetch) async throws -> T {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        // Return cached if available
        if behavior == .cachedOrFetch, let cachedDocument = currentCollection.first(where: { $0.id == id }) {
            return cachedDocument
        }

        // Fetch from remote
        logger?.trackEvent(event: Event.getDocumentStart(key: managerKey, documentId: id))

        do {
            let document = try await remote.getDocument(id: id)
            logger?.trackEvent(event: Event.getDocumentSuccess(key: managerKey, documentId: id))
            return document
        } catch {
            logger?.trackEvent(event: Event.getDocumentFail(key: managerKey, documentId: id, error: error))
            throw error
        }
    }

    /// Stream real-time updates for a single document.
    /// - Parameter id: The document ID.
    /// - Returns: An async stream of document updates (nil if document is deleted).
    public func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> {
        Task {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.streamDocumentStart(key: managerKey, documentId: id))
        return remote.streamDocument(id: id)
    }

    // MARK: - Read: Filtered

    /// Get documents filtered by a condition synchronously from cache.
    ///
    /// Returns empty if `startListening()` has not been called and no local persistence is available.
    /// - Parameter predicate: Filtering condition.
    /// - Returns: Filtered array of documents.
    public func getDocuments(where predicate: (T) -> Bool) -> [T] {
        return currentCollection.filter(predicate)
    }

    /// Get documents filtered by a condition asynchronously — returns cached if available, otherwise fetches from remote.
    /// - Parameter predicate: Filtering condition.
    /// - Returns: Filtered array of documents.
    /// - Throws: Error if fetch fails.
    public func getDocumentsAsync(where predicate: (T) -> Bool) async throws -> [T] {
        let collection = try await getCollectionAsync()
        return collection.filter(predicate)
    }

    /// Query documents using QueryBuilder.
    /// - Parameter buildQuery: Closure to build the query.
    /// - Returns: Array of documents matching the query filters from remote.
    /// - Throws: Error if query fails.
    public func getDocumentsAsync(buildQuery: (QueryBuilder) -> QueryBuilder) async throws -> [T] {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        let query = buildQuery(QueryBuilder())
        let filterCount = query.getFilters().count

        logger?.trackEvent(event: Event.getDocumentsQueryStart(key: managerKey, filterCount: filterCount))

        do {
            let documents = try await remote.getDocuments(query: query)
            logger?.trackEvent(event: Event.getDocumentsQuerySuccess(key: managerKey, count: documents.count, filterCount: filterCount))
            return documents
        } catch {
            logger?.trackEvent(event: Event.getDocumentsQueryFail(key: managerKey, filterCount: filterCount, error: error))
            throw error
        }
    }

    // MARK: - Write

    /// Save a complete document to remote.
    /// - Parameter document: The document to save.
    /// - Throws: Error if save fails.
    public func saveDocument(_ document: T) async throws {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.saveStart(key: managerKey, documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(key: managerKey, documentId: document.id))

            // Clear pending writes for this document since save succeeded
            if enableLocalPersistence && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: document.id)
            }
        } catch {
            logger?.trackEvent(event: Event.saveFail(key: managerKey, documentId: document.id, error: error))
            throw error
        }
    }

    /// Update a document with a dictionary of fields.
    /// - Parameters:
    ///   - id: The document ID.
    ///   - data: Dictionary of fields to update.
    /// - Throws: Error if update fails.
    public func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.updateStart(key: managerKey, documentId: id))

        do {
            try await remote.updateDocument(id: id, data: data)
            logger?.trackEvent(event: Event.updateSuccess(key: managerKey, documentId: id))

            // Clear pending writes for this document since update succeeded
            if enableLocalPersistence && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: id)
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(key: managerKey, documentId: id, error: error))

            // Add to pending writes if enabled (include document ID)
            if enableLocalPersistence {
                addPendingWrite(documentId: id, data: data)
            }

            throw error
        }
    }

    /// Delete a document from the collection.
    /// - Parameter id: The document ID.
    /// - Throws: Error if deletion fails.
    public func deleteDocument(id: String) async throws {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.deleteStart(key: managerKey, documentId: id))

        do {
            try await remote.deleteDocument(id: id)
            logger?.trackEvent(event: Event.deleteSuccess(key: managerKey, documentId: id))
        } catch {
            logger?.trackEvent(event: Event.deleteFail(key: managerKey, documentId: id, error: error))
            throw error
        }
    }

    // MARK: - Private: Collection Update Handler

    private func handleCollectionUpdate(_ collection: [T]) {
        currentCollection = collection

        Task {
            try? await local?.saveCollection(managerKey: managerKey, collection)
        }
        logger?.trackEvent(event: Event.collectionUpdated(key: managerKey, count: collection.count))
    }

    // MARK: - Private: Bulk Load

    private func bulkLoadCollection() async {
        logger?.trackEvent(event: Event.bulkLoadStart(key: managerKey))

        do {
            let collection = try await remote.getCollection()
            handleCollectionUpdate(collection)
            logger?.trackEvent(event: Event.bulkLoadSuccess(key: managerKey, count: collection.count))
        } catch {
            logger?.trackEvent(event: Event.bulkLoadFail(key: managerKey, error: error))
        }
    }

    // MARK: - Private: Listener

    private func startListener() {
        logger?.trackEvent(event: Event.listenerStart(key: managerKey))
        listenerFailedToAttach = false

        stopListener()

        let (updates, deletions) = remote.streamCollectionUpdates()

        updatesListenerTask = Task { @MainActor in
            await handleCollectionUpdates(updates)
        }

        deletionsListenerTask = Task { @MainActor in
            await handleCollectionDeletions(deletions)
        }
    }

    private func handleCollectionUpdates(_ updates: AsyncThrowingStream<T, Error>) async {
        var isFirstUpdate = true

        do {
            for try await document in updates {
                // Reset retry count on successful connection
                self.listenerRetryCount = 0

                // Log success only on first update (listener connected successfully)
                if isFirstUpdate {
                    logger?.trackEvent(event: Event.listenerSuccess(key: managerKey, count: currentCollection.count))
                    isFirstUpdate = false
                }

                // Update or add document in collection
                if let index = currentCollection.firstIndex(where: { $0.id == document.id }) {
                    currentCollection[index] = document
                } else {
                    currentCollection.append(document)
                }

                // Save to local persistence
                Task {
                    try? await local?.saveCollection(managerKey: managerKey, currentCollection)
                }
            }
        } catch {
            logger?.trackEvent(event: Event.listenerFail(key: managerKey, error: error))
            self.listenerFailedToAttach = true

            // Exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max)
            self.listenerRetryCount += 1
            let delay = min(pow(2.0, Double(self.listenerRetryCount)), 60.0)

            logger?.trackEvent(event: Event.listenerRetrying(key: managerKey, retryCount: self.listenerRetryCount, delaySeconds: delay))

            // Schedule retry with exponential backoff
            self.listenerRetryTask?.cancel()
            self.listenerRetryTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                if !Task.isCancelled && self.listenerFailedToAttach {
                    self.startListener()
                }
            }
        }
    }

    private func handleCollectionDeletions(_ deletions: AsyncThrowingStream<String, Error>) async {
        do {
            for try await documentId in deletions {
                // Remove document from collection
                currentCollection.removeAll { $0.id == documentId }

                // Save to local persistence
                Task {
                    try? await local?.saveCollection(managerKey: managerKey, currentCollection)
                }
            }
        } catch {
            logger?.trackEvent(event: Event.listenerFail(key: managerKey, error: error))
            self.listenerFailedToAttach = true
        }
    }

    private func stopListener() {
        updatesListenerTask?.cancel()
        updatesListenerTask = nil
        deletionsListenerTask?.cancel()
        deletionsListenerTask = nil
        listenerRetryTask?.cancel()
        listenerRetryTask = nil
        listenerRetryCount = 0
    }

    // MARK: - Private: Pending Writes

    private func addPendingWrite(documentId: String, data: [String: any DMCodableSendable]) {
        // Find existing pending write for this document
        if let existingIndex = pendingWrites.firstIndex(where: { $0.documentId == documentId }) {
            // Merge new fields into existing write (new values overwrite old)
            let mergedWrite = pendingWrites[existingIndex].merging(with: data)
            pendingWrites[existingIndex] = mergedWrite
        } else {
            // No existing write for this document, add new one
            let newWrite = PendingWrite(documentId: documentId, fields: data)
            pendingWrites.append(newWrite)
        }

        try? local?.savePendingWrites(managerKey: managerKey, pendingWrites)
        logger?.trackEvent(event: Event.pendingWriteAdded(key: managerKey, count: pendingWrites.count))
    }

    private func clearPendingWrites(forDocumentId documentId: String) {
        let originalCount = pendingWrites.count
        pendingWrites.removeAll { $0.documentId == documentId }

        if originalCount != pendingWrites.count {
            try? local?.savePendingWrites(managerKey: managerKey, pendingWrites)
            logger?.trackEvent(event: Event.pendingWritesCleared(key: managerKey, documentId: documentId, remainingCount: pendingWrites.count))
        }
    }

    private func syncPendingWrites() async {
        guard !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(key: managerKey, count: pendingWrites.count))

        var successCount = 0
        var failedWrites: [PendingWrite] = []

        for write in pendingWrites {
            // Pending writes need a document ID — skip if not present
            guard let documentId = write.documentId else {
                failedWrites.append(write)
                continue
            }

            do {
                try await remote.updateDocument(id: documentId, data: write.fields)
                successCount += 1
            } catch {
                failedWrites.append(write)
            }
        }

        // Update pending writes with only failed ones
        pendingWrites = failedWrites
        try? local?.savePendingWrites(managerKey: managerKey, pendingWrites)

        logger?.trackEvent(event: Event.syncPendingWritesComplete(key: managerKey, synced: successCount, failed: failedWrites.count))
    }

    // MARK: - Errors

    public enum DataManagerError: LocalizedError {
        case documentNotFound(id: String)

        public var errorDescription: String? {
            switch self {
            case .documentNotFound(let id):
                return "Document not found: \(id)"
            }
        }
    }

    // MARK: - Events

    enum Event: DataSyncLogEvent {
        case getCollectionStart(key: String)
        case getCollectionSuccess(key: String, count: Int)
        case getCollectionFail(key: String, error: Error)
        case getDocumentStart(key: String, documentId: String)
        case getDocumentSuccess(key: String, documentId: String)
        case getDocumentFail(key: String, documentId: String, error: Error)
        case streamDocumentStart(key: String, documentId: String)
        case getDocumentsQueryStart(key: String, filterCount: Int)
        case getDocumentsQuerySuccess(key: String, count: Int, filterCount: Int)
        case getDocumentsQueryFail(key: String, filterCount: Int, error: Error)
        case bulkLoadStart(key: String)
        case bulkLoadSuccess(key: String, count: Int)
        case bulkLoadFail(key: String, error: Error)
        case listenerStart(key: String)
        case listenerSuccess(key: String, count: Int)
        case listenerFail(key: String, error: Error)
        case listenerRetrying(key: String, retryCount: Int, delaySeconds: Double)
        case listenerStopped(key: String)
        case saveStart(key: String, documentId: String)
        case saveSuccess(key: String, documentId: String)
        case saveFail(key: String, documentId: String, error: Error)
        case updateStart(key: String, documentId: String)
        case updateSuccess(key: String, documentId: String)
        case updateFail(key: String, documentId: String, error: Error)
        case deleteStart(key: String, documentId: String)
        case deleteSuccess(key: String, documentId: String)
        case deleteFail(key: String, documentId: String, error: Error)
        case collectionUpdated(key: String, count: Int)
        case pendingWriteAdded(key: String, count: Int)
        case pendingWritesCleared(key: String, documentId: String, remainingCount: Int)
        case cachesCleared(key: String)
        case syncPendingWritesStart(key: String, count: Int)
        case syncPendingWritesComplete(key: String, synced: Int, failed: Int)

        var eventName: String {
            switch self {
            case .getCollectionStart(let key):              return "\(key)_getCollection_start"
            case .getCollectionSuccess(let key, _):         return "\(key)_getCollection_success"
            case .getCollectionFail(let key, _):            return "\(key)_getCollection_fail"
            case .getDocumentStart(let key, _):             return "\(key)_getDocument_start"
            case .getDocumentSuccess(let key, _):           return "\(key)_getDocument_success"
            case .getDocumentFail(let key, _, _):           return "\(key)_getDocument_fail"
            case .streamDocumentStart(let key, _):          return "\(key)_streamDocument_start"
            case .getDocumentsQueryStart(let key, _):       return "\(key)_getDocumentsQuery_start"
            case .getDocumentsQuerySuccess(let key, _, _):  return "\(key)_getDocumentsQuery_success"
            case .getDocumentsQueryFail(let key, _, _):     return "\(key)_getDocumentsQuery_fail"
            case .bulkLoadStart(let key):                   return "\(key)_bulkLoad_start"
            case .bulkLoadSuccess(let key, _):              return "\(key)_bulkLoad_success"
            case .bulkLoadFail(let key, _):                 return "\(key)_bulkLoad_fail"
            case .listenerStart(let key):                   return "\(key)_listener_start"
            case .listenerSuccess(let key, _):              return "\(key)_listener_success"
            case .listenerFail(let key, _):                 return "\(key)_listener_fail"
            case .listenerRetrying(let key, _, _):          return "\(key)_listener_retrying"
            case .listenerStopped(let key):                 return "\(key)_listener_stopped"
            case .saveStart(let key, _):                    return "\(key)_save_start"
            case .saveSuccess(let key, _):                  return "\(key)_save_success"
            case .saveFail(let key, _, _):                  return "\(key)_save_fail"
            case .updateStart(let key, _):                  return "\(key)_update_start"
            case .updateSuccess(let key, _):                return "\(key)_update_success"
            case .updateFail(let key, _, _):                return "\(key)_update_fail"
            case .deleteStart(let key, _):                  return "\(key)_delete_start"
            case .deleteSuccess(let key, _):                return "\(key)_delete_success"
            case .deleteFail(let key, _, _):                return "\(key)_delete_fail"
            case .collectionUpdated(let key, _):            return "\(key)_collectionUpdated"
            case .pendingWriteAdded(let key, _):            return "\(key)_pendingWriteAdded"
            case .pendingWritesCleared(let key, _, _):      return "\(key)_pendingWritesCleared"
            case .cachesCleared(let key):                   return "\(key)_cachesCleared"
            case .syncPendingWritesStart(let key, _):       return "\(key)_syncPendingWrites_start"
            case .syncPendingWritesComplete(let key, _, _): return "\(key)_syncPendingWrites_complete"
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
            case .bulkLoadSuccess(_, let count), .listenerSuccess(_, let count), .collectionUpdated(_, let count):
                dict["count"] = count
            case .bulkLoadFail(_, let error), .listenerFail(_, let error):
                dict.merge(error.eventParameters)
            case .listenerRetrying(_, let retryCount, let delaySeconds):
                dict["retry_count"] = retryCount
                dict["delay_seconds"] = delaySeconds
            case .getDocumentStart(_, let documentId), .getDocumentSuccess(_, let documentId),
                 .streamDocumentStart(_, let documentId),
                 .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId):
                dict["document_id"] = documentId
            case .getDocumentFail(_, let documentId, let error),
                 .saveFail(_, let documentId, let error),
                 .updateFail(_, let documentId, let error), .deleteFail(_, let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            case .pendingWriteAdded(_, let count):
                dict["pending_write_count"] = count
            case .pendingWritesCleared(_, let documentId, let remainingCount):
                dict["document_id"] = documentId
                dict["remaining_count"] = remainingCount
            case .syncPendingWritesStart(_, let count):
                dict["pending_write_count"] = count
            case .syncPendingWritesComplete(_, let synced, let failed):
                dict["synced_count"] = synced
                dict["failed_count"] = failed
            default:
                break
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .getCollectionFail, .getDocumentFail, .getDocumentsQueryFail, .bulkLoadFail, .listenerFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
