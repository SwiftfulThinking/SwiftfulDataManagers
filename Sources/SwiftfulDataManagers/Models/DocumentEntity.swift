//
//  DocumentEntity.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import SwiftData

/// SwiftData entity for local persistence of collection documents
///
/// **Architecture Note:**
/// This is the persistence layer model used exclusively by SwiftDataCollectionPersistence.
/// The public API uses DMProtocol conforming structs for data transfer.
/// Conversion between DocumentEntity and document models happens in the persistence layer.
///
/// **SwiftData Constraint:**
/// This class cannot be generic because @Model macro doesn't support generic classes.
/// Type information is encoded in the documentData using JSONEncoder/Decoder.
@Model
public final class DocumentEntity {
    /// Document unique identifier
    @Attribute(.unique) public var id: String

    /// Codable data stored as Data
    public var documentData: Data

    /// UTC timestamp when the document was created
    public var dateCreated: Date

    /// UTC timestamp when the document was last modified
    public var dateModified: Date

    // MARK: - Initialization

    public init(
        id: String,
        documentData: Data,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.documentData = documentData
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    // MARK: - Conversion

    /// Convert to public document model
    public func toDocument<T: DMProtocol>() throws -> T {
        return try JSONDecoder().decode(T.self, from: documentData)
    }

    /// Create entity from public document model
    public static func from<T: DMProtocol>(_ document: T) throws -> DocumentEntity {
        let data = try JSONEncoder().encode(document)
        return DocumentEntity(
            id: document.id,
            documentData: data,
            dateCreated: Date(),
            dateModified: Date()
        )
    }

    /// Update this entity with values from document
    public func update<T: DMProtocol>(from document: T) throws {
        self.id = document.id
        self.documentData = try JSONEncoder().encode(document)
        self.dateModified = Date()
    }
}
