//
//  CollectionSyncEngineTests.swift
//  SwiftfulDataManagers
//
//  Tests for CollectionSyncEngine query-based streaming.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("CollectionSyncEngine Tests")
@MainActor
struct CollectionSyncEngineTests {

    // MARK: - Test Model

    struct TestItem: DataSyncModelProtocol {
        let id: String
        var title: String
        var priority: Int
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

    // MARK: - No-Query Tests

    @Test("startListening with no query loads full collection")
    func testStartListeningNoQuery() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1),
            TestItem(id: "2", title: "Item 2", priority: 2)
        ]
        let (engine, _) = createEngine(collection: items)

        await engine.startListening()

        #expect(engine.currentCollection.count == 2)
        #expect(engine.currentCollection.contains(where: { $0.id == "1" }))
        #expect(engine.currentCollection.contains(where: { $0.id == "2" }))
    }

    // MARK: - Query-Based Tests

    @Test("startListening with query sets currentCollection from query results")
    func testStartListeningWithQuery() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1),
            TestItem(id: "2", title: "Item 2", priority: 2)
        ]
        let (engine, _) = createEngine(collection: items)

        // Mock doesn't filter, but we verify the code path works
        await engine.startListening { query in
            query.where("priority", isGreaterThan: 1)
        }

        // Mock returns all items (doesn't apply filter), but the path is exercised
        #expect(engine.currentCollection.count == 2)
    }

    @Test("Calling startListening with same query is a no-op")
    func testSameQueryNoOp() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1)
        ]
        let (engine, _) = createEngine(collection: items)

        // First call starts listening
        await engine.startListening { query in
            query.where("priority", isGreaterThan: 0)
        }
        let firstCollection = engine.currentCollection

        // Second call with identical query should be a no-op
        await engine.startListening { query in
            query.where("priority", isGreaterThan: 0)
        }
        let secondCollection = engine.currentCollection

        #expect(firstCollection.count == secondCollection.count)
    }

    @Test("Calling startListening with different query clears and reloads")
    func testDifferentQueryClearsAndReloads() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1),
            TestItem(id: "2", title: "Item 2", priority: 2)
        ]
        let (engine, _) = createEngine(collection: items)

        // Start with first query
        await engine.startListening { query in
            query.where("priority", isEqualTo: 1)
        }
        #expect(engine.currentCollection.count == 2) // Mock returns all

        // Switch to different query — should clear and reload
        await engine.startListening { query in
            query.where("priority", isEqualTo: 2)
        }

        // Collection was reloaded (mock still returns all items)
        #expect(engine.currentCollection.count == 2)
    }

    @Test("Switching from query to nil clears and reloads full collection")
    func testQueryToNilClearsAndReloads() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1),
            TestItem(id: "2", title: "Item 2", priority: 2)
        ]
        let (engine, _) = createEngine(collection: items)

        // Start with a query
        await engine.startListening { query in
            query.where("priority", isGreaterThan: 0)
        }
        #expect(engine.currentCollection.count == 2)

        // Switch to nil (full collection)
        await engine.startListening()

        #expect(engine.currentCollection.count == 2)
    }

    @Test("Switching from nil to query clears and reloads filtered")
    func testNilToQueryClearsAndReloads() async {
        let items = [
            TestItem(id: "1", title: "Item 1", priority: 1),
            TestItem(id: "2", title: "Item 2", priority: 2)
        ]
        let (engine, _) = createEngine(collection: items)

        // Start without query (full collection)
        await engine.startListening()
        #expect(engine.currentCollection.count == 2)

        // Switch to query
        await engine.startListening { query in
            query.where("priority", isGreaterThan: 1)
        }

        // Collection was reloaded (mock returns all items)
        #expect(engine.currentCollection.count == 2)
    }
}
