//
//  DocumentManagerSync.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import Observation

/// Synchronous document manager with real-time listener and local persistence.
///
/// Manages a single document with streaming updates, FileManager caching, and pending writes queue.
///
/// Example:
/// ```swift
/// let manager = DocumentManagerSync<Product>(
///     documentId: "product_123",
///     remote: FirebaseDocumentService(),
///     local: FileManagerDocumentPersistence(),
///     configuration: DataManagerConfiguration(),
///     logger: myLogger
/// )
///
/// // Start listening
/// await manager.startListening()
///
/// // Access current document
/// if let product = manager.currentDocument {
///     print(product.name)
/// }
/// ```
@MainActor
@Observable
open class DocumentManagerSync<T: DataModelProtocol> {

    // MARK: - Public Properties

    /// The current document (read-only for subclasses)
    public private(set) var currentDocument: T?

    // MARK: - Internal Properties

    internal let remote: any RemoteDocumentService<T>
    internal let local: any LocalDocumentPersistence<T>
    internal let configuration: DataManagerConfiguration
    public let logger: (any DataLogger)?

    // MARK: - Private Properties

    private var currentDocumentListenerTask: Task<Void, Error>?
    private var documentId: String?
    private var pendingWrites: [[String: any Sendable]] = []
    private var listenerFailedToAttach: Bool = false
    private var listenerRetryCount: Int = 0
    private var listenerRetryTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the DocumentManagerSync
    /// - Parameters:
    ///   - remote: Remote document service
    ///   - local: Local document persistence
    ///   - configuration: Manager configuration
    ///   - logger: Optional logger for analytics
    public init(
        remote: any RemoteDocumentService<T>,
        local: any LocalDocumentPersistence<T>,
        configuration: DataManagerConfiguration,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.local = local
        self.configuration = configuration
        self.logger = logger

        // Load cached document and document ID from local storage
        self.currentDocument = try? local.getDocument()
        self.documentId = try? local.getDocumentId()

        // Load pending writes if enabled
        if configuration.enablePendingWrites {
            self.pendingWrites = (try? local.getPendingWrites()) ?? []
        }
    }

    // MARK: - Public Methods

    /// Log in with a document ID and start listening for updates
    /// - Parameter documentId: The document ID to manage
    /// - Throws: Error if no document ID is set
    open func logIn(_ documentId: String) async throws {
        // If documentId is changing, log out first to clean up old listeners
        if self.documentId != documentId {
            logOut()
        }

        // Only update documentId if it's different
        if self.documentId != documentId {
            self.documentId = documentId
            try? local.saveDocumentId(documentId)
        }

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

    /// Stop listening for document updates
    /// - Parameter clearCaches: If true, clears in-memory state and local persistence
    open func stopListening(clearCaches: Bool = false) {
        logger?.trackEvent(event: Event.listenerStopped(key: configuration.managerKey))
        stopListener()

        if clearCaches {
            // Clear memory
            currentDocument = nil
            documentId = nil
            pendingWrites = []

            // Clear local persistence
            try? local.saveDocument(nil)
            try? local.saveDocumentId(nil)
            try? local.savePendingWrites([])

            logger?.trackEvent(event: Event.cachesCleared(key: configuration.managerKey))
        }
    }

    /// Get the current document synchronously from cache
    /// - Returns: The cached document, or nil if not available
    public func getDocument() -> T? {
        return currentDocument
    }

    /// Get the current document or throw if not available
    /// - Returns: The document
    /// - Throws: Error if no document available
    public func getDocumentOrThrow() throws -> T {
        guard let document = currentDocument else {
            throw DataManagerError.documentNotFound
        }
        return document
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

            // Clear pending writes since full document save succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.saveFail(key: configuration.managerKey, documentId: document.id, error: error))
            throw error
        }
    }

    /// Update document with a dictionary of fields
    /// - Parameter data: Dictionary of fields to update
    /// - Throws: Error if update fails or no document ID
    open func updateDocument(data: [String: any Sendable]) async throws {
        guard let documentId else {
            throw DataManagerError.noDocumentId
        }

        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.updateStart(key: configuration.managerKey, documentId: documentId))

        do {
            try await remote.updateDocument(id: documentId, data: data)
            logger?.trackEvent(event: Event.updateSuccess(key: configuration.managerKey, documentId: documentId))

            // Clear pending writes since update succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(key: configuration.managerKey, documentId: documentId, error: error))

            // Add to pending writes if enabled
            if configuration.enablePendingWrites {
                addPendingWrite(data)
            }

            throw error
        }
    }

    /// Delete the current document
    /// - Throws: Error if deletion fails or no document ID
    open func deleteDocument() async throws {
        guard let documentId else {
            throw DataManagerError.noDocumentId
        }

        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.deleteStart(key: configuration.managerKey, documentId: documentId))

        do {
            try await remote.deleteDocument(id: documentId)
            logger?.trackEvent(event: Event.deleteSuccess(key: configuration.managerKey, documentId: documentId))
            stopListening()
            handleDocumentUpdate(nil)
        } catch {
            logger?.trackEvent(event: Event.deleteFail(key: configuration.managerKey, documentId: documentId, error: error))
            throw error
        }
    }

    /// Get the current document ID
    /// - Returns: The document ID
    /// - Throws: Error if no document ID is set
    public final func getDocumentId() throws -> String {
        guard let documentId else {
            throw DataManagerError.noDocumentId
        }
        return documentId
    }

    // MARK: - Protected Methods (Overridable)

    /// Called when document data is updated. Subclasses can override to add custom behavior.
    /// - Important: Always call `super.handleDocumentUpdate(_:)` to ensure proper functionality.
    /// - Parameter document: The updated document (nil if document was deleted)
    open func handleDocumentUpdate(_ document: T?) {
        currentDocument = document

        if let document {
            try? local.saveDocument(document)
            logger?.trackEvent(event: Event.documentUpdated(key: configuration.managerKey, documentId: document.id))

            // Add document properties to logger
            logger?.addUserProperties(dict: document.eventParameters, isHighPriority: true)
        } else {
            try? local.saveDocument(nil)
            logger?.trackEvent(event: Event.documentDeleted(key: configuration.managerKey))
        }
    }

    // MARK: - Private Methods

    private func startListener() {
        guard let documentId else { return }

        logger?.trackEvent(event: Event.listenerStart(key: configuration.managerKey, documentId: documentId))
        listenerFailedToAttach = false

        currentDocumentListenerTask?.cancel()
        currentDocumentListenerTask = Task {
            do {
                let stream = remote.streamDocument(id: documentId)

                for try await document in stream {
                    // Reset retry count on successful connection
                    self.listenerRetryCount = 0

                    handleDocumentUpdate(document)

                    if document != nil {
                        logger?.trackEvent(event: Event.listenerSuccess(key: configuration.managerKey, documentId: documentId))
                    } else {
                        logger?.trackEvent(event: Event.listenerEmpty(key: configuration.managerKey, documentId: documentId))
                    }
                }
            } catch {
                logger?.trackEvent(event: Event.listenerFail(key: configuration.managerKey, documentId: documentId, error: error))
                self.listenerFailedToAttach = true

                // Exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max)
                self.listenerRetryCount += 1
                let delay = min(pow(2.0, Double(self.listenerRetryCount)), 60.0)

                logger?.trackEvent(event: Event.listenerRetrying(key: configuration.managerKey, documentId: documentId, retryCount: self.listenerRetryCount, delaySeconds: delay))

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
        currentDocumentListenerTask?.cancel()
        currentDocumentListenerTask = nil
        listenerRetryTask?.cancel()
        listenerRetryTask = nil
        listenerRetryCount = 0
    }

    private func addPendingWrite(_ data: [String: any Sendable]) {
        // DocumentManagerSync manages a single document, so merge all pending writes
        if let existingIndex = pendingWrites.indices.last {
            // Merge new fields into existing write (new values overwrite old)
            var mergedWrite = pendingWrites[existingIndex]
            for (key, value) in data {
                mergedWrite[key] = value
            }
            pendingWrites[existingIndex] = mergedWrite
        } else {
            // No existing writes, add new one
            pendingWrites.append(data)
        }

        try? local.savePendingWrites(pendingWrites)
        logger?.trackEvent(event: Event.pendingWriteAdded(key: configuration.managerKey, count: pendingWrites.count))
    }

    private func clearPendingWrites() {
        pendingWrites = []
        try? local.savePendingWrites(pendingWrites)
        logger?.trackEvent(event: Event.pendingWritesCleared(key: configuration.managerKey))
    }

    private func syncPendingWrites() async {
        guard let documentId, !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(key: configuration.managerKey, count: pendingWrites.count))

        var successCount = 0
        var failedWrites: [[String: any Sendable]] = []

        for write in pendingWrites {
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

    // MARK: - Errors

    public enum DataManagerError: LocalizedError {
        case noDocumentId
        case documentNotFound

        public var errorDescription: String? {
            switch self {
            case .noDocumentId:
                return "No document ID set"
            case .documentNotFound:
                return "Document not found"
            }
        }
    }

    // MARK: - Events

    enum Event: DataLogEvent {
        case listenerStart(key: String, documentId: String)
        case listenerSuccess(key: String, documentId: String)
        case listenerEmpty(key: String, documentId: String)
        case listenerFail(key: String, documentId: String, error: Error)
        case listenerRetrying(key: String, documentId: String, retryCount: Int, delaySeconds: Double)
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
        case documentUpdated(key: String, documentId: String)
        case documentDeleted(key: String)
        case pendingWriteAdded(key: String, count: Int)
        case pendingWritesCleared(key: String)
        case cachesCleared(key: String)
        case syncPendingWritesStart(key: String, count: Int)
        case syncPendingWritesComplete(key: String, synced: Int, failed: Int)

        var eventName: String {
            switch self {
            case .listenerStart(let key, _):                return "\(key)_listener_start"
            case .listenerSuccess(let key, _):              return "\(key)_listener_success"
            case .listenerEmpty(let key, _):                return "\(key)_listener_empty"
            case .listenerFail(let key, _, _):              return "\(key)_listener_fail"
            case .listenerRetrying(let key, _, _, _):       return "\(key)_listener_retrying"
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
            case .documentUpdated(let key, _):              return "\(key)_documentUpdated"
            case .documentDeleted(let key):                 return "\(key)_documentDeleted"
            case .pendingWriteAdded(let key, _):            return "\(key)_pendingWriteAdded"
            case .pendingWritesCleared(let key):            return "\(key)_pendingWritesCleared"
            case .cachesCleared(let key):                   return "\(key)_cachesCleared"
            case .syncPendingWritesStart(let key, _):       return "\(key)_syncPendingWrites_start"
            case .syncPendingWritesComplete(let key, _, _): return "\(key)_syncPendingWrites_complete"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .listenerStart(_, let documentId), .listenerSuccess(_, let documentId), .listenerEmpty(_, let documentId),
                 .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId),
                 .documentUpdated(_, let documentId):
                dict["document_id"] = documentId
            case .listenerFail(_, let documentId, let error),
                 .saveFail(_, let documentId, let error), .updateFail(_, let documentId, let error),
                 .deleteFail(_, let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            case .listenerRetrying(_, let documentId, let retryCount, let delaySeconds):
                dict["document_id"] = documentId
                dict["retry_count"] = retryCount
                dict["delay_seconds"] = delaySeconds
            case .pendingWriteAdded(_, let count):
                dict["pending_write_count"] = count
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
