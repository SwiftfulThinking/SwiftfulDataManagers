//
//  String+EXT.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

extension String {

    /// Sanitizes string for use as database key by removing whitespace and special characters (preserves case)
    ///
    /// Rules:
    /// - Preserves original case
    /// - Replaces whitespace with underscores
    /// - Removes special characters (keeps alphanumeric and underscores only)
    /// - Trims leading/trailing underscores
    /// - Collapses multiple consecutive underscores to single underscore
    ///
    /// Examples:
    /// - "Alpha" → "Alpha"
    /// - "Alpha 123" → "Alpha_123"
    /// - "My Level!" → "My_Level"
    /// - "  Hello   World  " → "Hello_World"
    /// - "" → "item" (fallback for empty strings)
    public func sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters() -> String {
        // Step 1: Replace whitespace with underscores
        var sanitized = self.replacingOccurrences(of: " ", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\t", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\n", with: "_")

        // Step 2: Remove all non-alphanumeric characters (except underscores)
        sanitized = sanitized.filter { $0.isLetter || $0.isNumber || $0 == "_" }

        // Step 3: Collapse multiple consecutive underscores to single underscore
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Step 4: Trim leading and trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Step 5: If result is empty, use a fallback
        if sanitized.isEmpty {
            return "item"
        }

        return sanitized
    }
}
