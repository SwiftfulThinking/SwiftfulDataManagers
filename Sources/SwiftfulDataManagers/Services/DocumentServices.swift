//
//  DocumentServices.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Protocol that combines remote and local services for DocumentManagerSync.
@MainActor
public protocol DocumentSyncServices {
    associatedtype T: DMProtocol
    var remote: any RemoteDocumentService<T> { get }
    var local: any LocalDocumentPersistence<T> { get }
}

/// Protocol that provides remote service for DocumentManagerAsync.
public protocol DocumentAsyncServices {
    associatedtype T: DMProtocol
    var remote: any RemoteDocumentService<T> { get }
}

/// Mock implementation of DocumentSyncServices for testing and previews.
@MainActor
public struct MockDocumentSyncServices<T: DMProtocol>: DocumentSyncServices {
    public let remote: any RemoteDocumentService<T>
    public let local: any LocalDocumentPersistence<T>

    public init(document: T? = nil) {
        self.remote = MockRemoteDocumentService<T>(document: document)
        self.local = MockLocalDocumentPersistence<T>(managerKey: "mock", document: document)
    }
}

/// Mock implementation of DocumentAsyncServices for testing and previews.
public struct MockDocumentAsyncServices<T: DMProtocol>: DocumentAsyncServices {
    public let remote: any RemoteDocumentService<T>

    public init(document: T? = nil) {
        self.remote = MockRemoteDocumentService<T>(document: document)
    }
}