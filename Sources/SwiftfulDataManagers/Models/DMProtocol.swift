//
//  DataSyncModelProtocol.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import IdentifiableByString

/// Protocol defining the required properties for a data model used with sync engines.
///
/// Data models must have a unique String identifier and be Codable and Sendable.
///
/// Example:
/// ```swift
/// struct Product: DataSyncModelProtocol {
///     let id: String
///     var name: String
///     var price: Double
///     var inventory: Int
/// }
/// ```
public protocol DataSyncModelProtocol: StringIdentifiable, Codable, Sendable {
    /// Unique identifier for the data model
    var id: String { get }

    /// Event parameters for analytics/logging (optional)
    var eventParameters: [String: Any] { get }
}

// MARK: - Default Implementation

public extension DataSyncModelProtocol {
    /// Default event parameters include just the ID
    var eventParameters: [String: Any] {
        return ["id": id]
    }
}
