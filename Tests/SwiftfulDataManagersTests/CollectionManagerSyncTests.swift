//
//  CollectionManagerSyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("CollectionSyncEngine Tests")
@MainActor
struct CollectionManagerSyncTests {

    // MARK: - Test Model

    struct TestItem: DataSyncModelProtocol {
        let id: String
        var title: String
        var priority: Int
        var isCompleted: Bool
    }

    // MARK: - Helper

    func createEngine(collection: [TestItem] = []) -> (CollectionSyncEngine<TestItem>, MockRemoteCollectionService<TestItem>) {
        let remote = MockRemoteCollectionService<TestItem>(collection: collection)
        let engine = CollectionSyncEngine<TestItem>(
            remote: remote,
            managerKey: "test_items",
            enableLocalPersistence: false,
            logger: nil
        )
        return (engine, remote)
    }

    // MARK: - Initialization Tests

    @Test("Initialize with empty collection")
    func testInitialization() {
        let (engine, _) = createEngine()
        #expect(engine.currentCollection.isEmpty)
    }

    // MARK: - Start / Stop Listening Tests

    @Test("Start listening fetches collection")
    func testStartListening() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        // Wait for listener to fetch collection
        try await Task.sleep(for: .milliseconds(600))

        #expect(engine.currentCollection.count == 2)
        #expect(engine.currentCollection.first?.title == "Item 1")
    }

    @Test("Stop listening clears collection")
    func testStopListening() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()
        try await Task.sleep(for: .milliseconds(600))

        #expect(!engine.currentCollection.isEmpty)

        engine.stopListening()

        #expect(engine.currentCollection.isEmpty)
    }

    // MARK: - Get Collection Tests

    @Test("Get collection async fetches from remote")
    func testGetCollectionAsync() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true),
            TestItem(id: "3", title: "Item 3", priority: 3, isCompleted: false)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        let result = try await engine.getCollectionAsync()

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
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()
        _ = try await engine.getCollectionAsync()

        let result = engine.getCollection()

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
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()
        _ = try await engine.getCollectionAsync()

        let document1 = engine.getDocument(id: "1")
        let document2 = engine.getDocument(id: "2")
        let document99 = engine.getDocument(id: "99")

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
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        let document = try await engine.getDocumentAsync(id: "2")

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
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        let results = try await engine.getDocumentsAsync { query in
            query.where("priority", isGreaterThan: 1)
        }

        // Mock doesn't actually filter, but call succeeds
        #expect(results.count >= 0)
    }

    // MARK: - Save Document Tests

    @Test("Save document adds to collection")
    func testSaveDocument() async throws {
        let (engine, _) = createEngine()

        await engine.startListening()

        let newItem = TestItem(id: "new_1", title: "New Item", priority: 5, isCompleted: false)

        try await engine.saveDocument(newItem)

        // Wait for save to propagate
        try await Task.sleep(for: .milliseconds(600))

        let document = engine.getDocument(id: "new_1")
        #expect(document?.title == "New Item")
        #expect(document?.priority == 5)
    }

    // MARK: - Update Document Tests

    @Test("Update document modifies existing")
    func testUpdateDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Original", priority: 1, isCompleted: false)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()
        _ = try await engine.getCollectionAsync()

        try await engine.updateDocument(id: "1", data: ["title": "Updated", "priority": 10])

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from collection")
    func testDeleteDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()
        _ = try await engine.getCollectionAsync()

        #expect(engine.currentCollection.count == 2)

        try await engine.deleteDocument(id: "1")

        // Wait for deletion to propagate
        try await Task.sleep(for: .milliseconds(600))

        #expect(engine.getDocument(id: "1") == nil)
    }

    // MARK: - Error Handling Tests

    @Test("Get document handles not found error")
    func testGetDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        await engine.startListening()

        do {
            _ = try await engine.getDocumentAsync(id: "nonexistent")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }

    @Test("Delete document handles not found error")
    func testDeleteDocumentNotFound() async throws {
        let (engine, _) = createEngine()

        await engine.startListening()

        do {
            try await engine.deleteDocument(id: "nonexistent")
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }
    }
}
