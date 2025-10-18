//
//  CollectionServices.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Protocol that combines remote and local services for CollectionManagerSync.
@MainActor
public protocol CollectionSyncServices {
    associatedtype T: DMProtocol
    var remote: any RemoteCollectionService<T> { get }
    var local: any LocalCollectionPersistence<T> { get }
}

/// Protocol that provides remote service for CollectionManagerAsync.
public protocol CollectionAsyncServices {
    associatedtype T: DMProtocol
    var remote: any RemoteCollectionService<T> { get }
}

/// Mock implementation of CollectionSyncServices for testing and previews.
@MainActor
public struct MockCollectionSyncServices<T: DMProtocol>: CollectionSyncServices {
    public let remote: any RemoteCollectionService<T>
    public let local: any LocalCollectionPersistence<T>

    public init(collection: [T] = []) {
        self.remote = MockRemoteCollectionService<T>(collection: collection)
        self.local = MockLocalCollectionPersistence<T>(managerKey: "mock", collection: collection)
    }
}

/// Mock implementation of CollectionAsyncServices for testing and previews.
public struct MockCollectionAsyncServices<T: DMProtocol>: CollectionAsyncServices {
    public let remote: any RemoteCollectionService<T>

    public init(collection: [T] = []) {
        self.remote = MockRemoteCollectionService<T>(collection: collection)
    }
}