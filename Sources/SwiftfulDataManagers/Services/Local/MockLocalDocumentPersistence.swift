//
//  MockLocalDocumentPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of LocalDocumentPersistence for testing and previews.
public final class MockLocalDocumentPersistence<T: DataSyncModelProtocol>: LocalDocumentPersistence, @unchecked Sendable {

    // MARK: - Properties

    private var documents: [String: T] = [:]
    private var documentIds: [String: String] = [:]
    private var pendingWrites: [String: [PendingWrite]] = [:]
    private let defaultDocument: T?

    // MARK: - Initialization

    public init(document: T? = nil) {
        self.defaultDocument = document
        if let document = document {
            // Store under a wildcard that will be returned for any key
            self.documents["*"] = document
            self.documentIds["*"] = document.id
        }
    }

    // MARK: - LocalDocumentPersistence Implementation

    public func saveDocument(managerKey: String, _ document: T?) throws {
        if let document = document {
            documents[managerKey] = document
        } else {
            documents.removeValue(forKey: managerKey)
        }
    }

    public func getDocument(managerKey: String) throws -> T? {
        // Return specific key if it exists, otherwise return wildcard default
        return documents[managerKey] ?? documents["*"]
    }

    public func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws {
        pendingWrites[managerKey] = writes
    }

    public func getPendingWrites(managerKey: String) throws -> [PendingWrite] {
        return pendingWrites[managerKey] ?? []
    }

    public func clearPendingWrites(managerKey: String) throws {
        pendingWrites[managerKey] = []
    }

    public func saveDocumentId(managerKey: String, _ id: String?) throws {
        if let id = id {
            documentIds[managerKey] = id
        } else {
            documentIds.removeValue(forKey: managerKey)
        }
    }

    public func getDocumentId(managerKey: String) throws -> String? {
        // Return specific key if it exists, otherwise return wildcard default
        return documentIds[managerKey] ?? documentIds["*"]
    }
}
