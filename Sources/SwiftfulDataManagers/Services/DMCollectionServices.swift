//
//  DMCollectionServices.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Protocol that combines remote and local services for CollectionManagerSync.
@MainActor
public protocol DMCollectionServices {
    associatedtype T: DMProtocol
    var remote: any RemoteCollectionService<T> { get }
    var local: any LocalCollectionPersistence<T> { get }
}

/// Mock implementation of DMCollectionServices for testing and previews.
@MainActor
public struct MockDMCollectionServices<T: DMProtocol>: DMCollectionServices {
    public let remote: any RemoteCollectionService<T>
    public let local: any LocalCollectionPersistence<T>

    public init(collection: [T] = []) {
        self.remote = MockRemoteCollectionService<T>(collection: collection)
        self.local = MockLocalCollectionPersistence<T>(managerKey: "mock", collection: collection)
    }
}