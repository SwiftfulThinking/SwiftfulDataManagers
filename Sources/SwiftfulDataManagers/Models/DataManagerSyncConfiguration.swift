//
//  DataManagerSyncConfiguration.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Configuration for synchronous data managers with local persistence.
public struct DataManagerSyncConfiguration: Sendable {

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

    // MARK: - Mock Factory

    /// Mock configuration with customizable parameters
    public static func mock(
        managerKey: String = "test",
        enablePendingWrites: Bool = true
    ) -> Self {
        DataManagerSyncConfiguration(
            managerKey: managerKey,
            enablePendingWrites: enablePendingWrites
        )
    }

    /// Mock with pending writes disabled
    public static func mockNoPendingWrites(managerKey: String = "test") -> Self {
        DataManagerSyncConfiguration(
            managerKey: managerKey,
            enablePendingWrites: false
        )
    }
}