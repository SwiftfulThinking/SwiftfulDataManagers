//
//  PendingWriteTests.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("PendingWrite Tests")
struct PendingWriteTests {

    // MARK: - Initialization Tests

    @Test("Initialize with fields only")
    func testInitWithFieldsOnly() {
        let fields: [String: any DMCodableSendable] = ["name": "John", "age": 30]
        let write = PendingWrite(fields: fields)

        #expect(write.documentId == nil)
        #expect(write.fields["name"] as? String == "John")
        #expect(write.fields["age"] as? Int == 30)
        #expect(write.createdAt.timeIntervalSinceNow < 1) // Created recently
    }

    @Test("Initialize with documentId and fields")
    func testInitWithDocumentIdAndFields() {
        let fields: [String: any DMCodableSendable] = ["name": "Jane", "email": "jane@example.com"]
        let write = PendingWrite(documentId: "user_123", fields: fields)

        #expect(write.documentId == "user_123")
        #expect(write.fields["name"] as? String == "Jane")
        #expect(write.fields["email"] as? String == "jane@example.com")
    }

    // MARK: - Merging Tests

    @Test("Merge with new fields")
    func testMergingWithNewFields() {
        let original = PendingWrite(
            documentId: "doc_1",
            fields: ["name": "John", "age": 30]
        )

        let merged = original.merging(with: ["email": "john@example.com", "city": "NYC"])

        #expect(merged.documentId == "doc_1")
        #expect(merged.fields["name"] as? String == "John")
        #expect(merged.fields["age"] as? Int == 30)
        #expect(merged.fields["email"] as? String == "john@example.com")
        #expect(merged.fields["city"] as? String == "NYC")
        #expect(merged.createdAt == original.createdAt) // Preserves original timestamp
    }

    @Test("Merge overwrites existing fields")
    func testMergingOverwritesExistingFields() {
        let original = PendingWrite(
            fields: ["name": "John", "age": 30, "city": "LA"]
        )

        let merged = original.merging(with: ["age": 31, "city": "NYC"])

        #expect(merged.fields["name"] as? String == "John")
        #expect(merged.fields["age"] as? Int == 31) // Updated
        #expect(merged.fields["city"] as? String == "NYC") // Updated
    }

    @Test("Merging preserves documentId")
    func testMergingPreservesDocumentId() {
        let original = PendingWrite(documentId: "user_456", fields: ["name": "Alice"])
        let merged = original.merging(with: ["age": 25])

        #expect(merged.documentId == "user_456")
    }

    // MARK: - Serialization Tests

    @Test("Convert to dictionary")
    func testToDictionary() {
        let write = PendingWrite(
            documentId: "doc_789",
            fields: ["name": "Bob", "age": 40, "active": true]
        )

        let dict = write.toDictionary()

        #expect(dict["_documentId"] as? String == "doc_789")
        #expect(dict["_createdAt"] as? TimeInterval != nil)
        #expect(dict["name"] as? String == "Bob")
        #expect(dict["age"] as? Int == 40)
        #expect(dict["active"] as? Bool == true)
    }

    @Test("Convert to dictionary without documentId")
    func testToDictionaryWithoutDocumentId() {
        let write = PendingWrite(fields: ["name": "Charlie", "score": 100])
        let dict = write.toDictionary()

        #expect(dict["_documentId"] == nil)
        #expect(dict["_createdAt"] as? TimeInterval != nil)
        #expect(dict["name"] as? String == "Charlie")
        #expect(dict["score"] as? Int == 100)
    }

    @Test("Round-trip serialization preserves data")
    func testRoundTripSerialization() {
        let original = PendingWrite(
            documentId: "test_123",
            fields: ["name": "Test User", "count": 42, "enabled": true]
        )

        let dict = original.toDictionary()
        let restored = PendingWrite.fromDictionary(dict)

        #expect(restored != nil)
        #expect(restored?.documentId == "test_123")
        #expect(restored?.fields["name"] as? String == "Test User")
        #expect(restored?.fields["count"] as? Int == 42)
        #expect(restored?.fields["enabled"] as? Bool == true)

        // Timestamps should be very close (within 1ms)
        if let restored = restored {
            let timeDiff = abs(restored.createdAt.timeIntervalSince(original.createdAt))
            #expect(timeDiff < 0.001)
        }
    }

    @Test("Deserialization from dictionary")
    func testFromDictionary() {
        let dict: [String: Any] = [
            "_documentId": "user_999",
            "_createdAt": Date().timeIntervalSince1970,
            "username": "testuser",
            "score": 150,
            "premium": true
        ]

        let write = PendingWrite.fromDictionary(dict)

        #expect(write != nil)
        #expect(write?.documentId == "user_999")
        #expect(write?.fields["username"] as? String == "testuser")
        #expect(write?.fields["score"] as? Int == 150)
        #expect(write?.fields["premium"] as? Bool == true)
    }

    @Test("Deserialization handles missing documentId")
    func testFromDictionaryWithoutDocumentId() {
        let dict: [String: Any] = [
            "_createdAt": Date().timeIntervalSince1970,
            "field1": "value1"
        ]

        let write = PendingWrite.fromDictionary(dict)

        #expect(write != nil)
        #expect(write?.documentId == nil)
        #expect(write?.fields["field1"] as? String == "value1")
    }

    @Test("Deserialization handles missing timestamp")
    func testFromDictionaryWithoutTimestamp() {
        let dict: [String: Any] = [
            "field1": "value1"
        ]

        let write = PendingWrite.fromDictionary(dict)

        #expect(write != nil)
        // Should use current date as fallback
        #expect(write?.createdAt.timeIntervalSinceNow ?? 100 < 1)
    }

    // MARK: - Complex Type Tests

    @Test("Handle nested arrays")
    func testNestedArrays() {
        let fields: [String: any DMCodableSendable] = [
            "tags": ["swift", "ios", "testing"],
            "scores": [10, 20, 30]
        ]
        let write = PendingWrite(fields: fields)

        let dict = write.toDictionary()
        let restored = PendingWrite.fromDictionary(dict)

        #expect(restored != nil)
        #expect((restored?.fields["tags"] as? [String])?.count == 3)
        #expect((restored?.fields["scores"] as? [Int])?.count == 3)
    }

    @Test("Handle nested dictionaries")
    func testNestedDictionaries() {
        let fields: [String: any DMCodableSendable] = [
            "metadata": ["version": "1.0", "platform": "iOS"],
            "counts": ["views": 100, "likes": 50]
        ]
        let write = PendingWrite(fields: fields)

        let dict = write.toDictionary()
        let restored = PendingWrite.fromDictionary(dict)

        #expect(restored != nil)
        // Arrays and nested dicts should be preserved
        #expect(restored?.fields["metadata"] != nil)
        #expect(restored?.fields["counts"] != nil)
    }

    @Test("Handle various numeric types")
    func testVariousNumericTypes() {
        let fields: [String: any DMCodableSendable] = [
            "int": 42,
            "double": 3.14,
            "bool": true
        ]
        let write = PendingWrite(fields: fields)

        let dict = write.toDictionary()
        let restored = PendingWrite.fromDictionary(dict)

        #expect(restored != nil)
        #expect(restored?.fields["int"] as? Int == 42)
        #expect(restored?.fields["double"] as? Double == 3.14)
        #expect(restored?.fields["bool"] as? Bool == true)
    }

    // MARK: - Edge Cases

    @Test("Handle empty fields")
    func testEmptyFields() {
        let write = PendingWrite(fields: [:])

        #expect(write.fields.isEmpty)

        let dict = write.toDictionary()
        let restored = PendingWrite.fromDictionary(dict)

        #expect(restored != nil)
        #expect(restored?.fields.isEmpty == true)
    }

    @Test("NSNull values are excluded during deserialization")
    func testNSNullExcluded() {
        let dict: [String: Any] = [
            "name": "Test",
            "nullValue": NSNull(),
            "age": 25
        ]

        let write = PendingWrite.fromDictionary(dict)

        #expect(write != nil)
        #expect(write?.fields["name"] as? String == "Test")
        #expect(write?.fields["age"] as? Int == 25)
        // NSNull should be excluded
        #expect(write?.fields["nullValue"] == nil)
    }

    @Test("Merging with empty dictionary")
    func testMergingWithEmptyDictionary() {
        let original = PendingWrite(fields: ["name": "Test"])
        let merged = original.merging(with: [:])

        #expect(merged.fields["name"] as? String == "Test")
        #expect(merged.fields.count == 1)
    }

    @Test("Multiple sequential merges")
    func testMultipleSequentialMerges() {
        let write = PendingWrite(fields: ["a": 1])
        let write2 = write.merging(with: ["b": 2])
        let write3 = write2.merging(with: ["c": 3])
        let write4 = write3.merging(with: ["a": 10]) // Overwrite

        #expect(write4.fields["a"] as? Int == 10) // Updated
        #expect(write4.fields["b"] as? Int == 2)
        #expect(write4.fields["c"] as? Int == 3)
        #expect(write4.fields.count == 3)
    }
}
