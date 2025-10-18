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
        logger?.trackEvent(event: Event.listenerStart(key: configuration.managerKey))

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
        logger?.trackEvent(event: Event.listenerStopped(key: configuration.managerKey))
        stopListener()

        if clearCaches {
            // Clear memory
            currentCollection = []
            pendingWrites = []

            // Clear local persistence
            try? local.saveCollection([])
            try? local.savePendingWrites([])

            logger?.trackEvent(event: Event.cachesCleared(key: configuration.managerKey))
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

        logger?.trackEvent(event: Event.saveStart(key: configuration.managerKey, documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(key: configuration.managerKey, documentId: document.id))

            // Clear pending writes for this document since save succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: document.id)
            }
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
        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.updateStart(key: configuration.managerKey, documentId: id))

        do {
            try await remote.updateDocument(id: id, data: data)
            logger?.trackEvent(event: Event.updateSuccess(key: configuration.managerKey, documentId: id))

            // Clear pending writes for this document since update succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites(forDocumentId: id)
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(key: configuration.managerKey, documentId: id, error: error))

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

        logger?.trackEvent(event: Event.deleteStart(key: configuration.managerKey, documentId: id))

        do {
            try await remote.deleteDocument(id: id)
            logger?.trackEvent(event: Event.deleteSuccess(key: configuration.managerKey, documentId: id))
        } catch {
            logger?.trackEvent(event: Event.deleteFail(key: configuration.managerKey, documentId: id, error: error))
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
        logger?.trackEvent(event: Event.collectionUpdated(key: configuration.managerKey, count: collection.count))
    }

    // MARK: - Private Methods

    private func startListener() {
        logger?.trackEvent(event: Event.listenerStart(key: configuration.managerKey))
        listenerFailedToAttach = false

        currentCollectionListenerTask?.cancel()
        currentCollectionListenerTask = Task {
            do {
                let stream = remote.streamCollection()

                for try await collection in stream {
                    // Reset retry count on successful connection
                    self.listenerRetryCount = 0

                    handleCollectionUpdate(collection)
                    logger?.trackEvent(event: Event.listenerSuccess(key: configuration.managerKey, count: collection.count))
                }
            } catch {
                logger?.trackEvent(event: Event.listenerFail(key: configuration.managerKey, error: error))
                self.listenerFailedToAttach = true

                // Exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max)
                self.listenerRetryCount += 1
                let delay = min(pow(2.0, Double(self.listenerRetryCount)), 60.0)

                logger?.trackEvent(event: Event.listenerRetrying(key: configuration.managerKey, retryCount: self.listenerRetryCount, delaySeconds: delay))

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
            logger?.trackEvent(event: Event.pendingWriteAdded(key: configuration.managerKey, count: pendingWrites.count))
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
        logger?.trackEvent(event: Event.pendingWriteAdded(key: configuration.managerKey, count: pendingWrites.count))
    }

    private func clearPendingWrites(forDocumentId documentId: String) {
        let originalCount = pendingWrites.count
        pendingWrites.removeAll { write in
            guard let writeDocId = write["id"] as? String else { return false }
            return writeDocId == documentId
        }

        if originalCount != pendingWrites.count {
            try? local.savePendingWrites(pendingWrites)
            logger?.trackEvent(event: Event.pendingWritesCleared(key: configuration.managerKey, documentId: documentId, remainingCount: pendingWrites.count))
        }
    }

    private func syncPendingWrites() async {
        guard !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(key: configuration.managerKey, count: pendingWrites.count))

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

        logger?.trackEvent(event: Event.syncPendingWritesComplete(key: configuration.managerKey, synced: successCount, failed: failedWrites.count))
    }

    // MARK: - Events

    enum Event: DataLogEvent {
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
            case .listenerSuccess(_, let count), .collectionUpdated(_, let count):
                dict["count"] = count
            case .listenerFail(_, let error):
                dict.merge(error.eventParameters)
            case .listenerRetrying(_, let retryCount, let delaySeconds):
                dict["retry_count"] = retryCount
                dict["delay_seconds"] = delaySeconds
            case .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId):
                dict["document_id"] = documentId
            case .saveFail(_, let documentId, let error),
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
            case .listenerFail, .saveFail, .updateFail, .deleteFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
