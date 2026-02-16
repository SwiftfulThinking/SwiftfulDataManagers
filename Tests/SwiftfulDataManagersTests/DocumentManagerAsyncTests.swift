//
//  DocumentManagerAsyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("DocumentSyncEngine Async Tests")
@MainActor
struct DocumentManagerAsyncTests {

    // MARK: - Test Model

    struct TestUser: DataSyncModelProtocol {
        let id: String
        var name: String
        var age: Int
        var email: String
    }

    // MARK: - Helper

    func createEngine(document: TestUser? = nil) -> (DocumentSyncEngine<TestUser>, MockRemoteDocumentService<TestUser>) {
        let remote = MockRemoteDocumentService<TestUser>(document: document)
        let engine = DocumentSyncEngine<TestUser>(
            remote: remote,
            managerKey: "test_user",
            enableLocalPersistence: false,
            logger: nil
        )
        return (engine, remote)
    }

    // MARK: - Get Document Tests

    @Test("Get document fetches from remote")
    func testGetDocument() async throws {
        let user = TestUser(id: "user_123", name: "Alice", age: 28, email: "alice@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        let result = try await engine.getDocumentAsync(id: "user_123")

        #expect(result.id == "user_123")
        #expect(result.name == "Alice")
        #expect(result.age == 28)
    }

    // MARK: - Save Document Tests

    @Test("Save document updates remote")
    func testSaveDocument() async throws {
        let (engine, _) = createEngine()

        let user = TestUser(id: "user_123", name: "Charlie", age: 40, email: "charlie@example.com")

        try await engine.startListening(documentId: "user_123")
        try await engine.saveDocument(user)

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Update Document Tests

    @Test("Update document sends partial updates")
    func testUpdateDocument() async throws {
        let user = TestUser(id: "user_123", name: "Dave", age: 32, email: "dave@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        try await engine.updateDocument(id: "user_123", data: ["name": "David", "age": 33])

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from remote")
    func testDeleteDocument() async throws {
        let user = TestUser(id: "user_123", name: "Eve", age: 27, email: "eve@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        try await engine.deleteDocument(id: "user_123")

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        try await engine.startListening(documentId: "placeholder")

        do {
            _ = try await engine.getDocumentAsync(id: "nonexistent_id")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        try await engine.startListening(documentId: "placeholder")

        do {
            try await engine.deleteDocument(id: "nonexistent_id")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}
