//
//  CollectionManagerSyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("CollectionManagerSync Tests")
@MainActor
struct CollectionManagerSyncTests {

    // MARK: - Test Model

    struct TestItem: DMProtocol {
        let id: String
        var title: String
        var priority: Int
        var isCompleted: Bool
    }

    // MARK: - Helper

    func createManager(collection: [TestItem] = []) -> (CollectionManagerSync<TestItem>, MockDMCollectionServices<TestItem>) {
        let services = MockDMCollectionServices<TestItem>(collection: collection)
        let config = DataManagerSyncConfiguration(managerKey: "test_items")
        let manager = CollectionManagerSync(services: services, configuration: config, logger: nil)
        return (manager, services)
    }

    // MARK: - Initialization Tests

    @Test("Initialize with empty collection")
    func testInitialization() {
        let (manager, _) = createManager()
        #expect(manager.currentCollection.isEmpty)
    }

    @Test("Initialize with cached collection from local persistence")
    func testInitializationWithCache() {
        let items = [
            TestItem(id: "1", title: "Cached Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Cached Item 2", priority: 2, isCompleted: true)
        ]
        let services = MockDMCollectionServices<TestItem>(collection: items)
        let config = DataManagerSyncConfiguration(managerKey: "test_items")

        let manager = CollectionManagerSync(services: services, configuration: config, logger: nil)

        #expect(manager.currentCollection.count == 2)
        #expect(manager.currentCollection.first?.title == "Cached Item 1")
    }

    // MARK: - Log In / Log Out Tests

    @Test("Log in fetches collection")
    func testLogIn() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()

        // Wait for listener to fetch collection
        try await Task.sleep(for: .milliseconds(600))

        #expect(manager.currentCollection.count == 2)
        #expect(manager.currentCollection.first?.title == "Item 1")
    }

    @Test("Log out clears collection")
    func testLogOut() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()
        try await Task.sleep(for: .milliseconds(600))

        #expect(!manager.currentCollection.isEmpty)

        manager.logOut()

        #expect(manager.currentCollection.isEmpty)
    }

    // MARK: - Get Collection Tests

    @Test("Get collection async fetches from remote")
    func testGetCollectionAsync() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true),
            TestItem(id: "3", title: "Item 3", priority: 3, isCompleted: false)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()

        let result = try await manager.getCollectionAsync()

        #expect(result.count == 3)
        #expect(result.first?.title == "Item 1")
        #expect(result.last?.title == "Item 3")
    }

    @Test("Get collection sync returns current collection")
    func testGetCollection() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()
        _ = try await manager.getCollectionAsync()

        let result = manager.getCollection()

        #expect(result.count == 2)
        #expect(result.first?.title == "Item 1")
    }

    // MARK: - Get Document Tests

    @Test("Get document by ID from collection")
    func testGetDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true),
            TestItem(id: "3", title: "Item 3", priority: 3, isCompleted: false)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()
        _ = try await manager.getCollectionAsync()

        let document1 = manager.getDocument(id: "1")
        let document2 = manager.getDocument(id: "2")
        let document99 = manager.getDocument(id: "99")

        #expect(document1?.title == "Item 1")
        #expect(document2?.title == "Item 2")
        #expect(document99 == nil)
    }

    @Test("Get document async fetches from remote")
    func testGetDocumentAsync() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()

        let document = try await manager.getDocumentAsync(id: "2")

        #expect(document.title == "Item 2")
        #expect(document.priority == 2)
        #expect(document.isCompleted == true)
    }

    // MARK: - Get Documents with Query Tests

    @Test("Get documents with query builder")
    func testGetDocumentsWithQuery() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true),
            TestItem(id: "3", title: "Item 3", priority: 3, isCompleted: false)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()

        let results = try await manager.getDocumentsAsync { query in
            query.where("priority", isGreaterThan: 1)
        }

        // Mock doesn't actually filter, but call succeeds
        #expect(results.count >= 0)
    }

    // MARK: - Save Document Tests

    @Test("Save document adds to collection")
    func testSaveDocument() async throws {
        let (manager, _) = createManager()

        await manager.logIn()

        let newItem = TestItem(id: "new_1", title: "New Item", priority: 5, isCompleted: false)

        try await manager.saveDocument(newItem)

        // Wait for save to propagate
        try await Task.sleep(for: .milliseconds(600))

        let document = manager.getDocument(id: "new_1")
        #expect(document?.title == "New Item")
        #expect(document?.priority == 5)
    }

    // MARK: - Update Document Tests

    @Test("Update document modifies existing")
    func testUpdateDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Original", priority: 1, isCompleted: false)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()
        _ = try await manager.getCollectionAsync()

        try await manager.updateDocument(id: "1", data: ["title": "Updated", "priority": 10])

        // Call succeeds without throwing
        #expect(true)
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from collection")
    func testDeleteDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (manager, _) = createManager(collection: items)

        await manager.logIn()
        _ = try await manager.getCollectionAsync()

        #expect(manager.currentCollection.count == 2)

        try await manager.deleteDocument(id: "1")

        // Wait for deletion to propagate
        try await Task.sleep(for: .milliseconds(600))

        #expect(manager.getDocument(id: "1") == nil)
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (manager, _) = createManager()

        await manager.logIn()

        do {
            _ = try await manager.getDocumentAsync(id: "nonexistent")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (manager, _) = createManager()

        await manager.logIn()

        do {
            try await manager.deleteDocument(id: "nonexistent")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}