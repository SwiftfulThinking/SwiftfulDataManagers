//
//  DataLogger.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

/// Protocol for logging data manager events.
///
/// Implement this protocol to integrate with your analytics system.
@MainActor
public protocol DataLogger: Sendable {
    /// Track an event
    /// - Parameter event: The event to track
    func trackEvent(event: DataLogEvent)

    /// Add properties to all future events
    /// - Parameters:
    ///   - dict: Dictionary of properties
    ///   - isHighPriority: Whether these are high priority properties
    func addUserProperties(dict: [String: Any], isHighPriority: Bool)
}

/// Protocol defining an event that can be logged.
public protocol DataLogEvent: Sendable {
    /// The name of the event
    var eventName: String { get }

    /// Optional parameters for the event
    var parameters: [String: Any]? { get }

    /// The type/severity of the event
    var type: DataLogType { get }
}

/// Event type/severity levels.
public enum DataLogType: Sendable {
    case info
    case analytic
    case severe
}
