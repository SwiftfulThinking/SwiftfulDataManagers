//
//  CollectionManagerSync.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import Observation

/// Synchronous collection manager with real-time listener and local persistence.
///
/// Manages a collection of documents with streaming updates, SwiftData caching, and pending writes queue.
/// Follows ProgressManager pattern: bulk load all documents, then stream changes.
///
/// Example:
/// ```swift
/// let manager = CollectionManagerSync<Product>(
///     remote: FirebaseCollectionService(),
///     local: SwiftDataCollectionPersistence(),
///     configuration: DataManagerConfiguration(),
///     logger: myLogger
/// )
///
/// // Start listening
/// await manager.startListening()
///
/// // Access current collection
/// for product in manager.currentCollection {
///     print(product.name)
/// }
/// ```
@MainActor
@Observable
open class CollectionManagerSync<T: DataModelProtocol> {

    // MARK: - Public Properties

    /// The current collection (read-only for subclasses)
    public private(set) var currentCollection: [T] = []

    // MARK: - Internal Properties

    internal let remote: any RemoteCollectionService<T>
    internal let local: any LocalCollectionPersistence<T>
    internal let configuration: DataManagerConfiguration
    internal let logger: (any DataLogger)?

    // MARK: - Private Properties

    private var currentCollectionListenerTask: Task<Void, Error>?
    private var pendingWrites: [[String: any Sendable]] = []
    private var listenerFailedToAttach: Bool = false
    private var listenerRetryCount: Int = 0
    private var listenerRetryTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the CollectionManagerSync
    /// - Parameters:
    ///   - remote: Remote collection service
    ///   - local: Local collection persistence
    ///   - configuration: Manager configuration
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteCollectionService<T>,
        local: any LocalCollectionPersistence<T>,
        configuration: DataManagerConfiguration,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.local = local
        self.configuration = configuration
        self.logger = logger

        // Load cached collection
        self.currentCollection = (try? local.getCollection()) ?? []

        // Load pending writes if enabled
        if configuration.enablePendingWrites {
            self.pendingWrites = (try? local.getPendingWrites()) ?? []
        }
    }

    // MARK: - Public Methods

    /// Log in and start listening for collection updates
    /// - Note: Pass nil to clear all data without starting listener
    open func logIn() async {
        logger?.trackEvent(event: Event.listenerStart)

        // Sync pending writes if enabled and available
        if configuration.enablePendingWrites && !pendingWrites.isEmpty {
            await syncPendingWrites()
        }

        // Start listener
        startListener()
    }

    /// Log out and clear all data
    open func logOut() {
        stopListening(clearCaches: true)
    }

    /// Stop listening for collection updates
    /// - Parameter clearCaches: If true, clears in-memory state and local persistence
    open func stopListening(clearCaches: Bool = false) {
        logger?.trackEvent(event: Event.listenerStopped)
        stopListener()

        if clearCaches {
            // Clear memory
            currentCollection = []
            pendingWrites = []

            // Clear local persistence
            try? local.saveCollection([])
            try? local.savePendingWrites([])

            logger?.trackEvent(event: Event.cachesCleared)
        }
    }

    /// Get the entire collection synchronously from cache
    /// - Returns: Array of all documents in the collection
    public func getCollection() -> [T] {
        return currentCollection
    }

    /// Get a single document by ID synchronously from cache
    /// - Parameter id: The document ID
    /// - Returns: The document if found, nil otherwise
    public func getDocument(id: String) -> T? {
        return currentCollection.first { $0.id == id }
    }

    /// Get documents filtered by a condition
    /// - Parameter predicate: Filtering condition
    /// - Returns: Filtered array of documents
    public func getDocuments(where predicate: (T) -> Bool) -> [T] {
        return currentCollection.filter(predicate)
    }

    /// Save a complete document
    /// - Parameter document: The document to save
    /// - Throws: Error if save fails
    open func saveDocument(_ document: T) async throws {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.saveStart(documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(documentId: document.id))

            // Clear pending writes for this document since save succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: document.id)
            }
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
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.updateStart(documentId: id))

        do {
            try await remote.updateDocument(id: id, data: data)
            logger?.trackEvent(event: Event.updateSuccess(documentId: id))

            // Clear pending writes for this document since update succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: id)
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(documentId: id, error: error))

            // Add to pending writes if enabled (include document ID)
            if configuration.enablePendingWrites {
                var writeData = data
                writeData["id"] = id
                addPendingWrite(writeData)
            }

            throw error
        }
    }

    /// Delete a document
    /// - Parameter id: The document ID
    /// - Throws: Error if deletion fails
    open func deleteDocument(id: String) async throws {
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.deleteStart(documentId: id))

        do {
            try await remote.deleteDocument(id: id)
            logger?.trackEvent(event: Event.deleteSuccess(documentId: id))
        } catch {
            logger?.trackEvent(event: Event.deleteFail(documentId: id, error: error))
            throw error
        }
    }

    // MARK: - Protected Methods (Overridable)

    /// Called when collection data is updated. Subclasses can override to add custom behavior.
    /// - Important: Always call `super.handleCollectionUpdate(_:)` to ensure proper functionality.
    /// - Parameter collection: The updated collection
    open func handleCollectionUpdate(_ collection: [T]) {
        currentCollection = collection

        try? local.saveCollection(collection)
        logger?.trackEvent(event: Event.collectionUpdated(count: collection.count))
    }

    // MARK: - Private Methods

    private func startListener() {
        logger?.trackEvent(event: Event.listenerStart)
        listenerFailedToAttach = false

        currentCollectionListenerTask?.cancel()
        currentCollectionListenerTask = Task {
            do {
                let stream = remote.streamCollection()

                for try await collection in stream {
                    // Reset retry count on successful connection
                    self.listenerRetryCount = 0

                    handleCollectionUpdate(collection)
                    logger?.trackEvent(event: Event.listenerSuccess(count: collection.count))
                }
            } catch {
                logger?.trackEvent(event: Event.listenerFail(error: error))
                self.listenerFailedToAttach = true

                // Exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max)
                self.listenerRetryCount += 1
                let delay = min(pow(2.0, Double(self.listenerRetryCount)), 60.0)

                logger?.trackEvent(event: Event.listenerRetrying(retryCount: self.listenerRetryCount, delaySeconds: delay))

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
    }

    private func stopListener() {
        currentCollectionListenerTask?.cancel()
        currentCollectionListenerTask = nil
        listenerRetryTask?.cancel()
        listenerRetryTask = nil
        listenerRetryCount = 0
    }

    private func addPendingWrite(_ data: [String: any Sendable]) {
        guard let documentId = data["id"] as? String else {
            // If no document ID, just append
            pendingWrites.append(data)
            try? local.savePendingWrites(pendingWrites)
            logger?.trackEvent(event: Event.pendingWriteAdded(count: pendingWrites.count))
            return
        }

        // Find existing pending write for this document
        if let existingIndex = pendingWrites.firstIndex(where: { write in
            guard let writeDocId = write["id"] as? String else { return false }
            return writeDocId == documentId
        }) {
            // Merge new fields into existing write (new values overwrite old)
            var mergedWrite = pendingWrites[existingIndex]
            for (key, value) in data where key != "id" {
                mergedWrite[key] = value
            }
            pendingWrites[existingIndex] = mergedWrite
        } else {
            // No existing write for this document, add new one
            pendingWrites.append(data)
        }

        try? local.savePendingWrites(pendingWrites)
        logger?.trackEvent(event: Event.pendingWriteAdded(count: pendingWrites.count))
    }

    private func clearPendingWrites(forDocumentId documentId: String) {
        let originalCount = pendingWrites.count
        pendingWrites.removeAll { write in
            guard let writeDocId = write["id"] as? String else { return false }
            return writeDocId == documentId
        }

        if originalCount != pendingWrites.count {
            try? local.savePendingWrites(pendingWrites)
            logger?.trackEvent(event: Event.pendingWritesCleared(documentId: documentId, remainingCount: pendingWrites.count))
        }
    }

    private func syncPendingWrites() async {
        guard !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(count: pendingWrites.count))

        var successCount = 0
        var failedWrites: [[String: any Sendable]] = []

        for write in pendingWrites {
            // Pending writes need a document ID - skip if not present
            guard let documentId = write["id"] as? String else {
                failedWrites.append(write)
                continue
            }

            do {
                try await remote.updateDocument(id: documentId, data: write)
                successCount += 1
            } catch {
                failedWrites.append(write)
            }
        }

        // Update pending writes with only failed ones
        pendingWrites = failedWrites
        try? local.savePendingWrites(pendingWrites)

        logger?.trackEvent(event: Event.syncPendingWritesComplete(synced: successCount, failed: failedWrites.count))
    }

    // MARK: - Events

    enum Event: DataLogEvent {
        case listenerStart
        case listenerSuccess(count: Int)
        case listenerFail(error: Error)
        case listenerRetrying(retryCount: Int, delaySeconds: Double)
        case listenerStopped
        case saveStart(documentId: String)
        case saveSuccess(documentId: String)
        case saveFail(documentId: String, error: Error)
        case updateStart(documentId: String)
        case updateSuccess(documentId: String)
        case updateFail(documentId: String, error: Error)
        case deleteStart(documentId: String)
        case deleteSuccess(documentId: String)
        case deleteFail(documentId: String, error: Error)
        case collectionUpdated(count: Int)
        case pendingWriteAdded(count: Int)
        case pendingWritesCleared(documentId: String, remainingCount: Int)
        case cachesCleared
        case syncPendingWritesStart(count: Int)
        case syncPendingWritesComplete(synced: Int, failed: Int)

        var eventName: String {
            switch self {
            case .listenerStart:                return "ColManS_listener_start"
            case .listenerSuccess:              return "ColManS_listener_success"
            case .listenerFail:                 return "ColManS_listener_fail"
            case .listenerRetrying:             return "ColManS_listener_retrying"
            case .listenerStopped:              return "ColManS_listener_stopped"
            case .saveStart:                    return "ColManS_save_start"
            case .saveSuccess:                  return "ColManS_save_success"
            case .saveFail:                     return "ColManS_save_fail"
            case .updateStart:                  return "ColManS_update_start"
            case .updateSuccess:                return "ColManS_update_success"
            case .updateFail:                   return "ColManS_update_fail"
            case .deleteStart:                  return "ColManS_delete_start"
            case .deleteSuccess:                return "ColManS_delete_success"
            case .deleteFail:                   return "ColManS_delete_fail"
            case .collectionUpdated:            return "ColManS_collection_updated"
            case .pendingWriteAdded:            return "ColManS_pending_write_added"
            case .pendingWritesCleared:         return "ColManS_pending_writes_cleared"
            case .cachesCleared:                return "ColManS_caches_cleared"
            case .syncPendingWritesStart:       return "ColManS_sync_pending_writes_start"
            case .syncPendingWritesComplete:    return "ColManS_sync_pending_writes_complete"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .listenerSuccess(let count), .collectionUpdated(let count):
                dict["count"] = count
            case .listenerFail(let error):
                dict.merge(error.eventParameters)
            case .listenerRetrying(let retryCount, let delaySeconds):
                dict["retry_count"] = retryCount
                dict["delay_seconds"] = delaySeconds
            case .saveStart(let documentId), .saveSuccess(let documentId),
                 .updateStart(let documentId), .updateSuccess(let documentId),
                 .deleteStart(let documentId), .deleteSuccess(let documentId):
                dict["document_id"] = documentId
            case .saveFail(let documentId, let error),
                 .updateFail(let documentId, let error), .deleteFail(let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            case .pendingWriteAdded(let count):
                dict["pending_write_count"] = count
            case .pendingWritesCleared(let documentId, let remainingCount):
                dict["document_id"] = documentId
                dict["remaining_count"] = remainingCount
            case .syncPendingWritesStart(let count):
                dict["pending_write_count"] = count
            case .syncPendingWritesComplete(let synced, let failed):
                dict["synced_count"] = synced
                dict["failed_count"] = failed
            default:
                break
            }

            return dict.isEmpty ? nil : dict
        }

        var type: DataLogType {
            switch self {
            case .listenerFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
