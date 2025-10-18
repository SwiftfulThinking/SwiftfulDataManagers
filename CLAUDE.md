# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run specific test suite
swift test --filter DocumentManagerSyncTests
swift test --filter CollectionManagerSyncTests
swift test --filter PendingWriteTests

# Run a single test
swift test --filter "DocumentManagerSyncTests.testInitialization"
```

## Architecture Overview

SwiftfulDataManagers is a Swift Package that provides data synchronization abstractions for iOS/macOS apps. It follows a layered architecture with clear separation between remote services, local persistence, and manager classes.

### Core Design Pattern

The package implements four types of data managers following a consistent pattern:

1. **DocumentManagerSync** - Manages a single document with real-time streaming and local persistence
2. **DocumentManagerAsync** - Manages a single document with async/await operations (no local persistence)
3. **CollectionManagerSync** - Manages collections with streaming updates and local persistence
4. **CollectionManagerAsync** - Manages collections with async/await operations (no local persistence)

### Key Architectural Decisions

#### Services Pattern
Sync managers use a combined services pattern where remote and local services are bundled:
- `DMDocumentServices` combines `RemoteDocumentService` + `LocalDocumentPersistence`
- `DMCollectionServices` combines `RemoteCollectionService` + `LocalCollectionPersistence`

#### Manager Key Parameter Pattern
Following SwiftfulGamification patterns, LocalPersistence protocols pass `managerKey` as a parameter to each method rather than storing it in the constructor. This provides flexibility for implementations:
```swift
func saveDocument(managerKey: String, _ document: T?) throws
func getDocument(managerKey: String) throws -> T?
```

#### Configuration Split
- `DataManagerSyncConfiguration` includes `enablePendingWrites` for offline support
- `DataManagerAsyncConfiguration` has no pending writes capability (remote-only)

#### Streaming Pattern for Sync Managers
CollectionManagerSync follows the "ProgressManager pattern" from SwiftfulGamification:
1. Bulk load all documents first via `getCollection()`
2. Stream individual updates/deletions via `streamCollectionUpdates()` returning `(updates: AsyncThrowingStream<T>, deletions: AsyncThrowingStream<String>)`

### Protocol Hierarchy

```
DMProtocol (base protocol combining Codable, Sendable, StringIdentifiable)
    ↓
RemoteDocumentService<T>     RemoteCollectionService<T>
LocalDocumentPersistence<T>  LocalCollectionPersistence<T>
    ↓                              ↓
DMDocumentServices            DMCollectionServices
    ↓                              ↓
DocumentManagerSync           CollectionManagerSync
DocumentManagerAsync          CollectionManagerAsync
```

### Mock Implementations

All protocols have corresponding Mock implementations for testing:
- `MockRemoteDocumentService` / `MockRemoteCollectionService`
- `MockLocalDocumentPersistence` / `MockLocalCollectionPersistence` (use wildcard pattern for default test data)
- `MockDMDocumentServices` / `MockDMCollectionServices`

### Pending Writes System

Sync managers support offline operations through `PendingWrite`:
- Failed operations are queued as pending writes
- Pending writes are synced on next successful connection
- Stored locally via FileManager or SwiftData persistence

### SwiftData Integration

`SwiftDataCollectionPersistence` provides SwiftData backing for collections:
- Uses `DocumentEntity<T>` as the SwiftData model
- Requires `managerKey` in init for ModelContainer setup
- Background context for bulk operations

## Related Packages

This package is designed to work with:
- **SwiftfulDataManagersFirebase**: Provides Firebase implementations of Remote services
- **SwiftfulGamification**: Reference implementation for patterns (StreakManager, ProgressManager)
- **SwiftfulStarterProject**: Example usage with UserManager2

## Testing Patterns

Tests use the Swift Testing framework (@Suite, @Test):
- Create managers with Mock services
- Test initialization with/without cached data
- Test CRUD operations and error handling
- Use `#expect` for assertions

## Common Gotchas

1. **managerKey must be sanitized** - No whitespace or special characters allowed
2. **Mock persistence uses wildcard pattern** - Default test data stored under "*" key
3. **Async managers don't have listeners** - Use Sync managers for real-time updates
4. **SwiftData persistence needs managerKey in init** - Different from FileManager pattern