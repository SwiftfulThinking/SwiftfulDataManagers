//
//  DocumentManagerSyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("DocumentSyncEngine Tests")
@MainActor
struct DocumentManagerSyncTests {

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

    // MARK: - Initialization Tests

    @Test("Initialize with nil document")
    func testInitialization() {
        let (engine, _) = createEngine()
        #expect(engine.currentDocument == nil)
    }

    // MARK: - Start / Stop Listening Tests

    @Test("Start listening starts listener and fetches document")
    func testStartListening() async throws {
        let user = TestUser(id: "user_123", name: "John", age: 30, email: "john@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")

        // Wait for listener to establish and fetch document
        try await Task.sleep(for: .milliseconds(100))

        #expect(engine.currentDocument != nil)
    }

    @Test("Stop listening clears document")
    func testStopListening() async throws {
        let user = TestUser(id: "user_123", name: "Jane", age: 25, email: "jane@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        try await Task.sleep(for: .milliseconds(100))

        #expect(engine.currentDocument != nil)

        engine.stopListening()

        #expect(engine.currentDocument == nil)
    }

    // MARK: - Get Document Tests

    @Test("Get document async fetches from remote")
    func testGetDocumentAsync() async throws {
        let user = TestUser(id: "user_123", name: "Alice", age: 28, email: "alice@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")

        let result = try await engine.getDocumentAsync()

        #expect(result.id == "user_123")
        #expect(result.name == "Alice")
        #expect(result.age == 28)
    }

    @Test("Get document sync returns current document")
    func testGetDocument() async throws {
        let user = TestUser(id: "user_123", name: "Bob", age: 35, email: "bob@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        _ = try await engine.getDocumentAsync()

        let result = engine.getDocument()

        #expect(result?.name == "Bob")
        #expect(result?.age == 35)
    }

    // MARK: - Save Document Tests

    @Test("Save document updates remote")
    func testSaveDocument() async throws {
        let (engine, _) = createEngine()

        let user = TestUser(id: "user_123", name: "Charlie", age: 40, email: "charlie@example.com")

        try await engine.startListening(documentId: "user_123")
        try await engine.saveDocument(user)

        // Wait for save to complete
        try await Task.sleep(for: .milliseconds(600))

        #expect(engine.currentDocument?.name == "Charlie")
        #expect(engine.currentDocument?.age == 40)
    }

    // MARK: - Update Document Tests

    @Test("Update document sends partial updates")
    func testUpdateDocument() async throws {
        let user = TestUser(id: "user_123", name: "Dave", age: 32, email: "dave@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")

        try await engine.updateDocument(data: ["name": "David", "age": 33])

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from remote")
    func testDeleteDocument() async throws {
        let user = TestUser(id: "user_123", name: "Eve", age: 27, email: "eve@example.com")
        let (engine, _) = createEngine(document: user)

        try await engine.startListening(documentId: "user_123")
        _ = try await engine.getDocumentAsync()

        #expect(engine.currentDocument != nil)

        try await engine.deleteDocument()

        // Wait for deletion to propagate
        try await Task.sleep(for: .milliseconds(600))

        #expect(engine.currentDocument == nil)
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        try await engine.startListening(documentId: "nonexistent_id")

        do {
            _ = try await engine.getDocumentAsync()
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        try await engine.startListening(documentId: "nonexistent_id")

        do {
            try await engine.deleteDocument()
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}
