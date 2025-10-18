//
//  DMDocumentServices.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Protocol that combines remote and local services for DocumentManagerSync.
@MainActor
public protocol DMDocumentServices {
    associatedtype T: DMProtocol
    var remote: any RemoteDocumentService<T> { get }
    var local: any LocalDocumentPersistence<T> { get }
}

/// Mock implementation of DMDocumentServices for testing and previews.
@MainActor
public struct MockDMDocumentServices<T: DMProtocol>: DMDocumentServices {
    public let remote: any RemoteDocumentService<T>
    public let local: any LocalDocumentPersistence<T>

    public init(document: T? = nil) {
        self.remote = MockRemoteDocumentService<T>(document: document)
        self.local = MockLocalDocumentPersistence<T>(managerKey: "mock", document: document)
    }
}