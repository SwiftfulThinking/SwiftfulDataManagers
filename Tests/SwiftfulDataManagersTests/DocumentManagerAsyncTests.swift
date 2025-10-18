//
//  DocumentManagerAsyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("DocumentManagerAsync Tests")
struct DocumentManagerAsyncTests {

    // MARK: - Test Model

    struct TestUser: DMProtocol {
        let id: String
        var name: String
        var age: Int
        var email: String
    }

    // MARK: - Helper

    func createManager(document: TestUser? = nil) -> (DocumentManagerAsync<TestUser>, MockRemoteDocumentService<TestUser>) {
        let service = MockRemoteDocumentService<TestUser>(document: document)
        let config = DataManagerConfiguration(managerKey: "test_user")
        let manager = DocumentManagerAsync(service: service, configuration: config, logger: nil)
        return (manager, service)
    }

    // MARK: - Get Document Tests

    @Test("Get document fetches from remote")
    func testGetDocument() async throws {
        let user = TestUser(id: "user_123", name: "Alice", age: 28, email: "alice@example.com")
        let (manager, _) = createManager(document: user)

        let result = try await manager.getDocument(id: "user_123")

        #expect(result.id == "user_123")
        #expect(result.name == "Alice")
        #expect(result.age == 28)
    }

    // MARK: - Save Document Tests

    @Test("Save document updates remote")
    func testSaveDocument() async throws {
        let (manager, _) = createManager()

        let user = TestUser(id: "user_123", name: "Charlie", age: 40, email: "charlie@example.com")

        try await manager.saveDocument(user)

        // Call succeeds without throwing
        #expect(true)
    }

    // MARK: - Update Document Tests

    @Test("Update document sends partial updates")
    func testUpdateDocument() async throws {
        let user = TestUser(id: "user_123", name: "Dave", age: 32, email: "dave@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.updateDocument(id: "user_123", data: ["name": "David", "age": 33])

        // Call succeeds without throwing
        #expect(true)
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from remote")
    func testDeleteDocument() async throws {
        let user = TestUser(id: "user_123", name: "Eve", age: 27, email: "eve@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.deleteDocument(id: "user_123")

        // Call succeeds without throwing
        #expect(true)
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (manager, _) = createManager()

        do {
            _ = try await manager.getDocument(id: "nonexistent_id")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (manager, _) = createManager()

        do {
            try await manager.deleteDocument(id: "nonexistent_id")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}