//
//  PendingWrite.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Represents a pending write operation for offline sync
///
/// Stores field updates with metadata for tracking and merging operations.
///
/// Example:
/// ```swift
/// let write = PendingWrite(
///     documentId: "user_123",
///     fields: ["name": "John", "age": 30]
/// )
///
/// // Merge with new fields
/// let updated = write.merging(with: ["age": 31, "email": "john@example.com"])
/// // Result: fields = ["name": "John", "age": 31, "email": "john@example.com"]
/// ```
public struct PendingWrite: Sendable {
    /// Optional document ID (nil for new documents)
    public let documentId: String?

    /// Fields to update
    public let fields: [String: any Codable & Sendable]

    /// Timestamp when the write was created
    public let createdAt: Date

    /// Initialize a new pending write
    /// - Parameters:
    ///   - documentId: Optional document ID
    ///   - fields: Fields to update
    public init(documentId: String? = nil, fields: [String: any Codable & Sendable]) {
        self.documentId = documentId
        self.fields = fields
        self.createdAt = Date()
    }

    /// Internal initializer with createdAt for deserialization
    internal init(documentId: String?, fields: [String: any Codable & Sendable], createdAt: Date) {
        self.documentId = documentId
        self.fields = fields
        self.createdAt = createdAt
    }

    /// Merge this write with new fields
    /// - Parameter newFields: New fields to merge (overwrites existing keys)
    /// - Returns: New PendingWrite with merged fields
    public func merging(with newFields: [String: any Codable & Sendable]) -> PendingWrite {
        var merged = self.fields
        for (key, value) in newFields {
            merged[key] = value
        }
        return PendingWrite(documentId: documentId, fields: merged, createdAt: createdAt)
    }

    /// Convert to dictionary for persistence
    /// - Returns: Dictionary representation with metadata
    public func toDictionary() -> [String: Any] {
        var dict = fields
        if let documentId {
            dict["_documentId"] = documentId
        }
        dict["_createdAt"] = createdAt.timeIntervalSince1970
        return dict
    }

    /// Create from persisted dictionary
    /// - Parameter dict: Dictionary from persistence
    /// - Returns: PendingWrite if valid, nil otherwise
    public static func fromDictionary(_ dict: [String: Any]) -> PendingWrite? {
        var fields = dict
        let documentId = fields.removeValue(forKey: "_documentId") as? String
        let timestamp = fields.removeValue(forKey: "_createdAt") as? TimeInterval
        let createdAt = timestamp.map { Date(timeIntervalSince1970: $0) } ?? Date()

        // Convert [String: Any] from JSON to [String: any Codable & Sendable]
        // JSONSerialization only produces: String, Int, Double, Bool, Array, Dictionary
        // All these types conform to Codable & Sendable (except NSNull which we skip)
        var codableFields: [String: any Codable & Sendable] = [:]
        for (key, value) in fields {
            // Skip NSNull (doesn't conform to Codable)
            guard !(value is NSNull) else { continue }

            // All JSON types are Codable. We verify they're Codable, then trust they're Sendable
            // (which is safe since JSONSerialization only produces Sendable types)
            if let codableValue = value as? Codable {
                codableFields[key] = makeCodableSendable(codableValue)
            }
        }

        return PendingWrite(documentId: documentId, fields: codableFields, createdAt: createdAt)
    }

    /// Helper to convert Codable to Codable & Sendable
    /// JSON types from JSONSerialization are always Sendable, but Swift can't prove it
    /// Uses unsafeBitCast to avoid compiler warnings about "always succeeds" cast
    @inline(__always)
    private static func makeCodableSendable(_ value: any Codable) -> any Codable & Sendable {
        unsafeBitCast(value, to: (any Codable & Sendable).self)
    }
}
