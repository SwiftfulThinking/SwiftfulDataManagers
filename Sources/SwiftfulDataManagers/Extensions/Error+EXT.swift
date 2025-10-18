//
//  Error+EXT.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

extension Error {
    /// Convert error to event parameters for logging
    var eventParameters: [String: Any] {
        var dict: [String: Any] = [:]
        dict["error_localized_description"] = localizedDescription
        dict["error_description"] = "\(self)"
        return dict
    }
}
