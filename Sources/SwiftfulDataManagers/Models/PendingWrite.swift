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
    public let fields: [String: any DMCodableSendable]

    /// Timestamp when the write was created
    public let createdAt: Date

    /// Initialize a new pending write
    /// - Parameters:
    ///   - documentId: Optional document ID
    ///   - fields: Fields to update
    public init(documentId: String? = nil, fields: [String: any DMCodableSendable]) {
        self.documentId = documentId
        self.fields = fields
        self.createdAt = Date()
    }

    /// Internal initializer with createdAt for deserialization
    internal init(documentId: String?, fields: [String: any DMCodableSendable], createdAt: Date) {
        self.documentId = documentId
        self.fields = fields
        self.createdAt = createdAt
    }

    /// Merge this write with new fields
    /// - Parameter newFields: New fields to merge (overwrites existing keys)
    /// - Returns: New PendingWrite with merged fields
    public func merging(with newFields: [String: any DMCodableSendable]) -> PendingWrite {
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

        // Convert [String: Any] from JSON to [String: any DMCodableSendable]
        // JSONSerialization only produces: String, Int, Double, Bool, Array, Dictionary
        // All these types conform to DMCodableSendable (except NSNull which we skip)
        var codableFields: [String: any DMCodableSendable] = [:]
        for (key, value) in fields {
            // Skip NSNull (doesn't conform to Codable)
            guard !(value is NSNull) else { continue }

            if let value = value as? any DMCodableSendable {
                codableFields[key] = value
            }
        }

        return PendingWrite(documentId: documentId, fields: codableFields, createdAt: createdAt)
    }
}

/// A protocol combining Codable and Sendable for types that can be stored in PendingWrite fields.
///
/// All standard JSON types (String, Int, Double, Bool, Array, Dictionary) conform to this automatically.
/// Extend your custom types with this protocol to use them in update dictionaries:
///
/// ```swift
/// struct MyCustomType: Codable, Sendable {
///     let name: String
/// }
///
/// extension MyCustomType: DMCodableSendable {}
/// ```
public protocol DMCodableSendable: Codable, Sendable {

}

// Conformance for standard JSON types
extension String: DMCodableSendable {}
extension Int: DMCodableSendable {}
extension Double: DMCodableSendable {}
extension Bool: DMCodableSendable {}
extension Array: DMCodableSendable where Element: Codable {}
extension Dictionary: DMCodableSendable where Key == String, Value: Codable {}
