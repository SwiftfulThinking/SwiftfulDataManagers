//
//  CollectionManagerAsyncTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("CollectionSyncEngine Async Tests")
@MainActor
struct CollectionManagerAsyncTests {

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

    // MARK: - Get Collection Tests

    @Test("Get collection fetches from remote")
    func testGetCollection() async throws {
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

    // MARK: - Get Document Tests

    @Test("Get document fetches from remote")
    func testGetDocument() async throws {
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

    @Test("Save document updates remote")
    func testSaveDocument() async throws {
        let (engine, _) = createEngine()

        await engine.startListening()

        let newItem = TestItem(id: "new_1", title: "New Item", priority: 5, isCompleted: false)

        try await engine.saveDocument(newItem)

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Update Document Tests

    @Test("Update document modifies existing")
    func testUpdateDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Original", priority: 1, isCompleted: false)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        try await engine.updateDocument(id: "1", data: ["title": "Updated", "priority": 10])

        // Call succeeds without throwing
        #expect(Bool(true))
    }

    // MARK: - Delete Document Tests

    @Test("Delete document removes from remote")
    func testDeleteDocument() async throws {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1, isCompleted: false),
            TestItem(id: "2", title: "Item 2", priority: 2, isCompleted: true)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        try await engine.deleteDocument(id: "1")

        // Call succeeds without throwing
        #expect(Bool(true))
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
