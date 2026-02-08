//
//  DocumentSyncEngine.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno.
//

import Foundation
import Observation

/// Real-time document sync engine with optional local persistence.
///
/// Manages a single document with streaming updates, optional FileManager caching,
/// and pending writes queue. Designed for composition (not subclassing).
///
/// Example:
/// ```swift
/// let engine = DocumentSyncEngine<UserModel>(
///     remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
///     configuration: DataManagerSyncConfiguration(managerKey: "user", enablePendingWrites: true),
///     logger: logManager
/// )
///
/// // Start real-time sync
/// try await engine.startListening(documentId: "user_123")
///
/// // Access current document (Observable — SwiftUI auto-updates)
/// if let user = engine.currentDocument {
///     print(user.name)
/// }
///
/// // Update fields
/// try await engine.updateDocument(data: ["name": "John"])
///
/// // Stop listening
/// engine.stopListening()
/// ```
@MainActor
@Observable
public final class DocumentSyncEngine<T: DMProtocol> {

    // MARK: - Public Properties

    /// The current document. Observable — SwiftUI views reading this will auto-update.
    public private(set) var currentDocument: T?

    /// The logger instance, accessible for domain-specific logging in consuming code.
    public let logger: (any DataLogger)?

    // MARK: - Internal Properties

    internal let remote: any RemoteDocumentService<T>
    internal let local: (any LocalDocumentPersistence<T>)?
    internal let configuration: DataManagerSyncConfiguration
    internal let enableLocalPersistence: Bool

    // MARK: - Private Properties

    private var currentDocumentListenerTask: Task<Void, Error>?
    private var documentId: String?
    private var pendingWrites: [PendingWrite] = []
    private var listenerFailedToAttach: Bool = false
    private var listenerRetryCount: Int = 0
    private var listenerRetryTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the DocumentSyncEngine.
    /// - Parameters:
    ///   - remote: The remote document service (e.g., FirebaseRemoteDocumentService)
    ///   - configuration: Manager configuration (managerKey)
    ///   - enableLocalPersistence: Whether to persist the document locally via FileManager and enable pending writes. Default `true`.
    ///   - logger: Optional logger for analytics events.
    public init(
        remote: any RemoteDocumentService<T>,
        configuration: DataManagerSyncConfiguration,
        enableLocalPersistence: Bool = true,
        logger: (any DataLogger)? = nil
    ) {
        self.remote = remote
        self.configuration = configuration
        self.enableLocalPersistence = enableLocalPersistence
        self.logger = logger

        if enableLocalPersistence {
            let persistence = FileManagerDocumentPersistence<T>()
            self.local = persistence

            // Load cached document and document ID from local storage
            self.currentDocument = try? persistence.getDocument(managerKey: configuration.managerKey)
            self.documentId = try? persistence.getDocumentId(managerKey: configuration.managerKey)

            // Load pending writes
            self.pendingWrites = (try? persistence.getPendingWrites(managerKey: configuration.managerKey)) ?? []
        } else {
            self.local = nil
        }
    }

    // MARK: - Lifecycle

    /// Start listening for real-time updates on a document.
    ///
    /// This will:
    /// 1. Clear old listeners if the document ID changed
    /// 2. Persist the document ID locally (if persistence is enabled)
    /// 3. Sync any pending writes
    /// 4. Start a real-time Firestore listener
    ///
    /// - Parameter documentId: The document ID to listen to.
    public func startListening(documentId: String) async throws {
        // If documentId is changing, stop old listener first
        if self.documentId != documentId {
            stopListening()
        }

        // Only update documentId if it's different
        if self.documentId != documentId {
            self.documentId = documentId
            try? local?.saveDocumentId(managerKey: configuration.managerKey, documentId)
        }

        // Sync pending writes if enabled and available
        if enableLocalPersistence && !pendingWrites.isEmpty {
            await syncPendingWrites()
        }

        // Start listener
        startListener()
    }

    /// Stop listening for real-time updates.
    ///
    /// - Parameter clearCaches: If true (default), clears `currentDocument`, document ID,
    ///   pending writes, and all local persistence. If false, only cancels the listener.
    public func stopListening(clearCaches: Bool = true) {
        logger?.trackEvent(event: Event.listenerStopped(key: configuration.managerKey))
        stopListener()

        if clearCaches {
            // Clear memory
            currentDocument = nil
            documentId = nil
            pendingWrites = []

            // Clear local persistence
            if enableLocalPersistence {
                try? local?.saveDocument(managerKey: configuration.managerKey, nil)
                try? local?.saveDocumentId(managerKey: configuration.managerKey, nil)
                try? local?.savePendingWrites(managerKey: configuration.managerKey, [])
            }

            logger?.trackEvent(event: Event.cachesCleared(key: configuration.managerKey))
        }
    }

    // MARK: - Read

    /// Get the current document synchronously from cache.
    /// - Returns: The cached document, or nil if not available.
    public func getDocument() -> T? {
        return currentDocument
    }

    /// Get the current document or throw if not available.
    /// - Returns: The document.
    /// - Throws: `DataManagerError.documentNotFound` if no document is cached.
    public func getDocumentOrThrow() throws -> T {
        guard let document = currentDocument else {
            throw DataManagerError.documentNotFound
        }
        return document
    }

    /// Get the document asynchronously.
    /// - Parameters:
    ///   - id: Optional document ID. If nil, uses the stored document ID from `startListening`.
    ///   - behavior: `.cachedOrFetch` (default) returns cached if available, `.alwaysFetch` always fetches from remote.
    /// - Returns: The document.
    /// - Throws: Error if fetch fails or no document ID is available.
    public func getDocumentAsync(id: String? = nil, behavior: FetchBehavior = .cachedOrFetch) async throws -> T {
        let resolvedId = id ?? documentId

        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        guard let resolvedId else {
            throw DataManagerError.noDocumentId
        }

        // Return cached if available (only for cachedOrFetch with no explicit ID)
        if behavior == .cachedOrFetch, id == nil, let currentDocument {
            return currentDocument
        }

        // Fetch from remote
        logger?.trackEvent(event: Event.getDocumentStart(key: configuration.managerKey, documentId: resolvedId))

        do {
            let document = try await remote.getDocument(id: resolvedId)
            logger?.trackEvent(event: Event.getDocumentSuccess(key: configuration.managerKey, documentId: resolvedId))
            return document
        } catch {
            logger?.trackEvent(event: Event.getDocumentFail(key: configuration.managerKey, documentId: resolvedId, error: error))
            throw error
        }
    }

    /// Get the current document ID.
    /// - Returns: The document ID.
    /// - Throws: `DataManagerError.noDocumentId` if no document ID is set.
    public func getDocumentId() throws -> String {
        guard let documentId else {
            throw DataManagerError.noDocumentId
        }
        return documentId
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

        logger?.trackEvent(event: Event.saveStart(key: configuration.managerKey, documentId: document.id))

        do {
            try await remote.saveDocument(document)
            logger?.trackEvent(event: Event.saveSuccess(key: configuration.managerKey, documentId: document.id))

            // Clear pending writes since full document save succeeded
            if enableLocalPersistence && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.saveFail(key: configuration.managerKey, documentId: document.id, error: error))
            throw error
        }
    }

    /// Update the document with a dictionary of fields.
    /// - Parameters:
    ///   - id: Optional document ID. If nil, uses the stored document ID from `startListening`.
    ///   - data: Dictionary of fields to update.
    /// - Throws: Error if update fails or no document ID is available.
    public func updateDocument(id: String? = nil, data: [String: any DMCodableSendable]) async throws {
        let resolvedId = id ?? documentId

        guard let resolvedId else {
            throw DataManagerError.noDocumentId
        }

        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.updateStart(key: configuration.managerKey, documentId: resolvedId))

        do {
            try await remote.updateDocument(id: resolvedId, data: data)
            logger?.trackEvent(event: Event.updateSuccess(key: configuration.managerKey, documentId: resolvedId))

            // Clear pending writes since update succeeded
            if enableLocalPersistence && !pendingWrites.isEmpty {
                clearPendingWrites()
            }
        } catch {
            logger?.trackEvent(event: Event.updateFail(key: configuration.managerKey, documentId: resolvedId, error: error))

            // Add to pending writes if enabled
            if enableLocalPersistence {
                addPendingWrite(data)
            }

            throw error
        }
    }

    /// Delete a document.
    /// - Parameter id: Optional document ID. If nil, uses the stored document ID from `startListening`.
    /// - Throws: Error if deletion fails or no document ID is available.
    public func deleteDocument(id: String? = nil) async throws {
        let resolvedId = id ?? documentId

        guard let resolvedId else {
            throw DataManagerError.noDocumentId
        }

        defer {
            if listenerFailedToAttach {
                startListener()
            }
        }

        logger?.trackEvent(event: Event.deleteStart(key: configuration.managerKey, documentId: resolvedId))

        do {
            try await remote.deleteDocument(id: resolvedId)
            logger?.trackEvent(event: Event.deleteSuccess(key: configuration.managerKey, documentId: resolvedId))
            stopListener()
            handleDocumentUpdate(nil)
        } catch {
            logger?.trackEvent(event: Event.deleteFail(key: configuration.managerKey, documentId: resolvedId, error: error))
            throw error
        }
    }

    // MARK: - Private: Document Update Handler

    private func handleDocumentUpdate(_ document: T?) {
        currentDocument = document

        if let document {
            try? local?.saveDocument(managerKey: configuration.managerKey, document)
            logger?.trackEvent(event: Event.documentUpdated(key: configuration.managerKey, documentId: document.id))

            // Add document properties to logger
            logger?.addUserProperties(dict: document.eventParameters, isHighPriority: true)
        } else {
            try? local?.saveDocument(managerKey: configuration.managerKey, nil)
            logger?.trackEvent(event: Event.documentDeleted(key: configuration.managerKey))
        }
    }

    // MARK: - Private: Listener

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

    // MARK: - Private: Pending Writes

    private func addPendingWrite(_ data: [String: any DMCodableSendable]) {
        // DocumentSyncEngine manages a single document, so merge all pending writes
        if let lastWrite = pendingWrites.last {
            // Merge new fields into existing write (new values overwrite old)
            let mergedWrite = lastWrite.merging(with: data)
            pendingWrites[pendingWrites.count - 1] = mergedWrite
        } else {
            // No existing writes, add new one
            let newWrite = PendingWrite(documentId: nil, fields: data)
            pendingWrites.append(newWrite)
        }

        try? local?.savePendingWrites(managerKey: configuration.managerKey, pendingWrites)
        logger?.trackEvent(event: Event.pendingWriteAdded(key: configuration.managerKey, count: pendingWrites.count))
    }

    private func clearPendingWrites() {
        pendingWrites = []
        try? local?.savePendingWrites(managerKey: configuration.managerKey, pendingWrites)
        logger?.trackEvent(event: Event.pendingWritesCleared(key: configuration.managerKey))
    }

    private func syncPendingWrites() async {
        guard let documentId, !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.syncPendingWritesStart(key: configuration.managerKey, count: pendingWrites.count))

        var successCount = 0
        var failedWrites: [PendingWrite] = []

        for write in pendingWrites {
            do {
                try await remote.updateDocument(id: documentId, data: write.fields)
                successCount += 1
            } catch {
                failedWrites.append(write)
            }
        }

        // Update pending writes with only failed ones
        pendingWrites = failedWrites
        try? local?.savePendingWrites(managerKey: configuration.managerKey, pendingWrites)

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
        case getDocumentStart(key: String, documentId: String)
        case getDocumentSuccess(key: String, documentId: String)
        case getDocumentFail(key: String, documentId: String, error: Error)
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
            case .getDocumentStart(let key, _):             return "\(key)_getDocument_start"
            case .getDocumentSuccess(let key, _):           return "\(key)_getDocument_success"
            case .getDocumentFail(let key, _, _):           return "\(key)_getDocument_fail"
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
            case .getDocumentStart(_, let documentId), .getDocumentSuccess(_, let documentId),
                 .listenerStart(_, let documentId), .listenerSuccess(_, let documentId), .listenerEmpty(_, let documentId),
                 .saveStart(_, let documentId), .saveSuccess(_, let documentId),
                 .updateStart(_, let documentId), .updateSuccess(_, let documentId),
                 .deleteStart(_, let documentId), .deleteSuccess(_, let documentId),
                 .documentUpdated(_, let documentId):
                dict["document_id"] = documentId
            case .getDocumentFail(_, let documentId, let error),
                 .listenerFail(_, let documentId, let error),
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
