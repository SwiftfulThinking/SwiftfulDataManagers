//
//  Dictionary+EXT.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation

extension Dictionary where Key == String, Value == Any {
    /// Merge another dictionary into this one
    mutating func merge(_ other: [String: Any]) {
        for (key, value) in other {
            self[key] = value
        }
    }
}
