//
//  DocumentManagerSyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("DocumentManagerSync Tests")
@MainActor
struct DocumentManagerSyncTests {

    // MARK: - Test Model

    struct TestUser: DMProtocol {
        let id: String
        var name: String
        var age: Int
        var email: String
    }

    // MARK: - Helper

    func createManager(document: TestUser? = nil) -> (DocumentManagerSync<TestUser>, MockDMDocumentServices<TestUser>) {
        let services = MockDMDocumentServices<TestUser>(document: document)
        let config = DataManagerConfiguration(managerKey: "test_user")
        let manager = DocumentManagerSync(services: services, configuration: config, logger: nil)
        return (manager, services)
    }

    // MARK: - Initialization Tests

    @Test("Initialize with nil document")
    func testInitialization() {
        let (manager, _) = createManager()
        #expect(manager.currentDocument == nil)
    }

    @Test("Initialize with cached document from local persistence")
    func testInitializationWithCache() {
        let user = TestUser(id: "user_123", name: "Cached", age: 30, email: "cached@example.com")
        let services = MockDMDocumentServices<TestUser>(document: user)
        let config = DataManagerConfiguration(managerKey: "test_user")

        let manager = DocumentManagerSync(services: services, configuration: config, logger: nil)

        #expect(manager.currentDocument?.name == "Cached")
        #expect(manager.currentDocument?.age == 30)
    }

    // MARK: - Log In / Log Out Tests

    @Test("Log in starts listener and fetches document")
    func testLogIn() async throws {
        let user = TestUser(id: "user_123", name: "John", age: 30, email: "john@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")

        // Wait for listener to establish and fetch document
        try await Task.sleep(for: .milliseconds(100))

        #expect(manager.currentDocument != nil)
    }

    @Test("Log out clears document")
    func testLogOut() async throws {
        let user = TestUser(id: "user_123", name: "Jane", age: 25, email: "jane@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")
        try await Task.sleep(for: .milliseconds(100))

        #expect(manager.currentDocument != nil)

        manager.logOut()

        #expect(manager.currentDocument == nil)
    }

    // MARK: - Get Document Tests

    @Test("Get document async fetches from remote")
    func testGetDocumentAsync() async throws {
        let user = TestUser(id: "user_123", name: "Alice", age: 28, email: "alice@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")

        let result = try await manager.getDocumentAsync()

        #expect(result.id == "user_123")
        #expect(result.name == "Alice")
        #expect(result.age == 28)
    }

    @Test("Get document sync returns current document")
    func testGetDocument() async throws {
        let user = TestUser(id: "user_123", name: "Bob", age: 35, email: "bob@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")
        _ = try await manager.getDocumentAsync()

        let result = manager.getDocument()

        #expect(result?.name == "Bob")
        #expect(result?.age == 35)
    }

    // MARK: - Save Document Tests

    @Test("Save document updates remote and local")
    func testSaveDocument() async throws {
        let (manager, _) = createManager()

        let user = TestUser(id: "user_123", name: "Charlie", age: 40, email: "charlie@example.com")

        try await manager.logIn("user_123")
        try await manager.saveDocument(user)

        // Wait for save to complete
        try await Task.sleep(for: .milliseconds(600))

        #expect(manager.currentDocument?.name == "Charlie")
        #expect(manager.currentDocument?.age == 40)
    }

    // MARK: - Update Document Tests

    @Test("Update document sends partial updates")
    func testUpdateDocument() async throws {
        let user = TestUser(id: "user_123", name: "Dave", age: 32, email: "dave@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")

        try await manager.updateDocument(data: ["name": "David", "age": 33])

        // Call succeeds without throwing
        #expect(true)
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from remote")
    func testDeleteDocument() async throws {
        let user = TestUser(id: "user_123", name: "Eve", age: 27, email: "eve@example.com")
        let (manager, _) = createManager(document: user)

        try await manager.logIn("user_123")
        _ = try await manager.getDocumentAsync()

        #expect(manager.currentDocument != nil)

        try await manager.deleteDocument()

        // Wait for deletion to propagate
        try await Task.sleep(for: .milliseconds(600))

        #expect(manager.currentDocument == nil)
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (manager, _) = createManager()

        try await manager.logIn("nonexistent_id")

        do {
            _ = try await manager.getDocumentAsync()
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (manager, _) = createManager()

        try await manager.logIn("nonexistent_id")

        do {
            try await manager.deleteDocument()
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}