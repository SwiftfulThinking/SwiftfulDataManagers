//
//  DataManagerConfiguration.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Configuration for data managers.
public struct DataManagerConfiguration: Sendable {

    /// Whether to enable pending writes queue for failed operations
    public let enablePendingWrites: Bool

    /// Initialize configuration
    /// - Parameter enablePendingWrites: Whether to enable pending writes queue (default: true)
    public init(enablePendingWrites: Bool = true) {
        self.enablePendingWrites = enablePendingWrites
    }
}
