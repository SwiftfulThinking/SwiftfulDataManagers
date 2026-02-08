//
//  FetchBehavior.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno.
//

import Foundation

/// Controls how async fetch methods resolve data.
public enum FetchBehavior {
    /// Return cached data if available, otherwise fetch from remote.
    case cachedOrFetch
    /// Always fetch from remote, ignoring cached data.
    case alwaysFetch
}
