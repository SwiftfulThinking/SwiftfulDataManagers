//
//  DataManagerAsyncConfiguration.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Configuration for asynchronous data managers without local persistence.
public struct DataManagerAsyncConfiguration: Sendable {

    /// Manager key for unique identification (e.g., "user", "settings", "profile")
    public let managerKey: String

    /// Initialize configuration
    /// - Parameter managerKey: Manager key for unique identification
    public init(managerKey: String) {
        precondition(
            managerKey == managerKey.sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters(),
            "managerKey must be sanitized (no whitespace, no special characters)"
        )

        self.managerKey = managerKey
    }
}