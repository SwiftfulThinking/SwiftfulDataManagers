//
//  DataManagerConfiguration.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Configuration for data managers.
public struct DataManagerConfiguration: Sendable {

    /// Manager key for unique identification (e.g., "user", "settings", "profile")
    public let managerKey: String

    /// Whether to enable pending writes queue for failed operations
    public let enablePendingWrites: Bool

    /// Initialize configuration
    /// - Parameters:
    ///   - managerKey: Manager key for unique identification
    ///   - enablePendingWrites: Whether to enable pending writes queue (default: true)
    public init(
        managerKey: String,
        enablePendingWrites: Bool = true
    ) {
        precondition(
            managerKey == managerKey.sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters(),
            "managerKey must be sanitized (no whitespace, no special characters)"
        )

        self.managerKey = managerKey
        self.enablePendingWrites = enablePendingWrites
    }
}
