//
//  MockLocalDocumentPersistence.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Mock implementation of LocalDocumentPersistence for testing and previews.
public final class MockLocalDocumentPersistence<T: DataModelProtocol>: LocalDocumentPersistence, @unchecked Sendable {

    // MARK: - Properties

    private var cachedDocument: T?
    private var cachedDocumentId: String?
    private var cachedPendingWrites: [[String: any Sendable]] = []

    // MARK: - Initialization

    public init(document: T? = nil) {
        self.cachedDocument = document
        self.cachedDocumentId = document?.id
    }

    // MARK: - LocalDocumentPersistence Implementation

    public func saveDocument(_ document: T?) throws {
        cachedDocument = document
    }

    public func getDocument() throws -> T? {
        return cachedDocument
    }

    public func savePendingWrites(_ writes: [[String: any Sendable]]) throws {
        cachedPendingWrites = writes
    }

    public func getPendingWrites() throws -> [[String: any Sendable]] {
        return cachedPendingWrites
    }

    public func clearPendingWrites() throws {
        cachedPendingWrites = []
    }

    public func saveDocumentId(_ id: String?) throws {
        cachedDocumentId = id
    }

    public func getDocumentId() throws -> String? {
        return cachedDocumentId
    }
}
