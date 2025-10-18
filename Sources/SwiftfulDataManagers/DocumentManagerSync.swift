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
    internal let logger: (any DataLogger)?

    // MARK: - Private Properties

    private var currentDocumentListenerTask: Task<Void, Error>?
    private var documentId: String?
    private var pendingWrites: [[String: any Sendable]] = []
    private var listenerFailedToAttach: Bool = false

    // MARK: - Initialization

    /// Initialize the DocumentManagerSync
    /// - Parameters:
    ///   - documentId: The ID of the document to manage (optional, can be set later)
    ///   - remote: Remote document service
    ///   - local: Local document persistence
    ///   - configuration: Manager configuration
    ///   - logger: Optional logger for analytics
    public init(
        documentId: String? = nil,
        remote: any RemoteDocumentService<T>,
        local: any LocalDocumentPersistence<T>,
        configuration: DataManagerConfiguration = DataManagerConfiguration(),
        logger: (any DataLogger)? = nil
    ) {
        self.documentId = documentId
        self.remote = remote
        self.local = local
        self.configuration = configuration
        self.logger = logger

        // Load cached document and document ID
        self.currentDocument = try? local.getDocument()
        if documentId == nil {
            self.documentId = try? local.getDocumentId()
        }

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
        // Set document ID
        self.documentId = documentId
        try? local.saveDocumentId(documentId)

        logger?.trackEvent(event: Event.listenerStart(documentId: documentId))

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
        logger?.trackEvent(event: Event.listenerStopped)
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

            logger?.trackEvent(event: Event.cachesCleared)
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

        logger?.trackEvent(event: Event.saveStart(documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(documentId: document.id))

            // Clear pending writes since full document save succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.saveFail(documentId: document.id, error: error))
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

        logger?.trackEvent(event: Event.updateStart(documentId: documentId))

        do {
            try await remote.updateDocument(id: documentId, data: data)
            logger?.trackEvent(event: Event.updateSuccess(documentId: documentId))

            // Clear pending writes since update succeeded
            if configuration.enablePendingWrites && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(documentId: documentId, error: error))

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

        logger?.trackEvent(event: Event.deleteStart(documentId: documentId))

        do {
            try await remote.deleteDocument(id: documentId)
            logger?.trackEvent(event: Event.deleteSuccess(documentId: documentId))
            stopListening()
            handleDocumentUpdate(nil)
        } catch {
            logger?.trackEvent(event: Event.deleteFail(documentId: documentId, error: error))
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
            logger?.trackEvent(event: Event.documentUpdated(documentId: document.id))

            // Add document properties to logger
            logger?.addUserProperties(dict: document.eventParameters, isHighPriority: true)
        } else {
            try? local.saveDocument(nil)
            logger?.trackEvent(event: Event.documentDeleted)
        }
    }

    // MARK: - Private Methods

    private func startListener() {
        guard let documentId else { return }

        logger?.trackEvent(event: Event.listenerStart(documentId: documentId))
        listenerFailedToAttach = false

        currentDocumentListenerTask?.cancel()
        currentDocumentListenerTask = Task {
            do {
                let stream = remote.streamDocument(id: documentId)

                for try await document in stream {
                    handleDocumentUpdate(document)

                    if document != nil {
                        logger?.trackEvent(event: Event.listenerSuccess(documentId: documentId))
                    } else {
                        logger?.trackEvent(event: Event.listenerEmpty(documentId: documentId))
                    }
                }
            } catch {
                logger?.trackEvent(event: Event.listenerFail(documentId: documentId, error: error))
                self.listenerFailedToAttach = true
            }
        }
    }

    private func stopListener() {
        currentDocumentListenerTask?.cancel()
        currentDocumentListenerTask = nil
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
        logger?.trackEvent(event: Event.pendingWriteAdded(count: pendingWrites.count))
    }

    private func clearPendingWrites() {
        pendingWrites = []
        try? local.savePendingWrites(pendingWrites)
        logger?.trackEvent(event: Event.pendingWritesCleared)
    }

    private func syncPendingWrites() async {
        guard let documentId, !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(count: pendingWrites.count))

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

        logger?.trackEvent(event: Event.syncPendingWritesComplete(synced: successCount, failed: failedWrites.count))
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
        case listenerStart(documentId: String)
        case listenerSuccess(documentId: String)
        case listenerEmpty(documentId: String)
        case listenerFail(documentId: String, error: Error)
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
        case documentUpdated(documentId: String)
        case documentDeleted
        case pendingWriteAdded(count: Int)
        case pendingWritesCleared
        case cachesCleared
        case syncPendingWritesStart(count: Int)
        case syncPendingWritesComplete(synced: Int, failed: Int)

        var eventName: String {
            switch self {
            case .listenerStart:                return "DocManS_listener_start"
            case .listenerSuccess:              return "DocManS_listener_success"
            case .listenerEmpty:                return "DocManS_listener_empty"
            case .listenerFail:                 return "DocManS_listener_fail"
            case .listenerStopped:              return "DocManS_listener_stopped"
            case .saveStart:                    return "DocManS_save_start"
            case .saveSuccess:                  return "DocManS_save_success"
            case .saveFail:                     return "DocManS_save_fail"
            case .updateStart:                  return "DocManS_update_start"
            case .updateSuccess:                return "DocManS_update_success"
            case .updateFail:                   return "DocManS_update_fail"
            case .deleteStart:                  return "DocManS_delete_start"
            case .deleteSuccess:                return "DocManS_delete_success"
            case .deleteFail:                   return "DocManS_delete_fail"
            case .documentUpdated:              return "DocManS_document_updated"
            case .documentDeleted:              return "DocManS_document_deleted"
            case .pendingWriteAdded:            return "DocManS_pending_write_added"
            case .pendingWritesCleared:         return "DocManS_pending_writes_cleared"
            case .cachesCleared:                return "DocManS_caches_cleared"
            case .syncPendingWritesStart:       return "DocManS_sync_pending_writes_start"
            case .syncPendingWritesComplete:    return "DocManS_sync_pending_writes_complete"
            }
        }

        var parameters: [String: Any]? {
            var dict: [String: Any] = [:]

            switch self {
            case .listenerStart(let documentId), .listenerSuccess(let documentId), .listenerEmpty(let documentId),
                 .saveStart(let documentId), .saveSuccess(let documentId),
                 .updateStart(let documentId), .updateSuccess(let documentId),
                 .deleteStart(let documentId), .deleteSuccess(let documentId),
                 .documentUpdated(let documentId):
                dict["document_id"] = documentId
            case .listenerFail(let documentId, let error),
                 .saveFail(let documentId, let error), .updateFail(let documentId, let error),
                 .deleteFail(let documentId, let error):
                dict["document_id"] = documentId
                dict.merge(error.eventParameters)
            case .pendingWriteAdded(let count):
                dict["pending_write_count"] = count
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
