### 🚀 Learn how to build and use this package: https://www.swiftful-thinking.com/offers/REyNLwwH

# Data Managers for Swift 6 📊

Reusable data synchronization managers for Swift applications, built for Swift 6. Includes `@Observable` support.

![Platform: iOS/macOS](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)

Pre-built dependencies*:

- Mock: Included
- Firebase: https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase

\* Created another? Send the url in [issues](https://github.com/SwiftfulThinking/SwiftfulDataManagers/issues)! 🥳

## Features

- ✅ **Document Management**: Single document with real-time sync or async operations
- ✅ **Collection Management**: Document collections with streaming updates
- ✅ **Offline Support**: Pending writes queue for failed operations
- ✅ **Local Persistence**: FileManager and SwiftData backing

## Quick Examples

```swift
// Document Manager - Real-time sync
Task {
    try await documentManager.logIn("user_123")
    try await documentManager.updateDocument(data: ["name": "John"])
    print(documentManager.currentDocument) // Real-time updated document
}

// Collection Manager - Streaming updates
Task {
    await collectionManager.logIn()
    try await collectionManager.saveDocument(product)
    print(collectionManager.currentCollection) // Auto-updated collection
}

// Async managers - No local persistence
Task {
    let user = try await asyncManager.getDocument(id: "user_123")
    try await asyncManager.updateDocument(id: "user_123", data: ["age": 30])
}
```

## Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

#### Create instances of managers:

```swift
// Document Manager with real-time sync
let documentManager = DocumentManagerSync(
    services: any DMDocumentServices,
    configuration: DataManagerSyncConfiguration,
    logger: DataLogger?
)

// Collection Manager with real-time sync
let collectionManager = CollectionManagerSync(
    services: any DMCollectionServices,
    configuration: DataManagerSyncConfiguration,
    logger: DataLogger?
)

// Async managers (no local persistence)
let asyncDocumentManager = DocumentManagerAsync(
    service: any RemoteDocumentService,
    configuration: DataManagerAsyncConfiguration,
    logger: DataLogger?
)
```

#### Development vs Production:

```swift
#if DEBUG
let documentManager = DocumentManagerSync(
    services: MockDMDocumentServices(),
    configuration: .mock(managerKey: "user")
)
#else
let documentManager = DocumentManagerSync(
    services: FirebaseDMDocumentServices(),
    configuration: DataManagerSyncConfiguration(managerKey: "user")
)
#endif
```

#### Optionally add to SwiftUI environment as @Observable

```swift
Text("Hello, world!")
    .environment(documentManager)
    .environment(collectionManager)
```

</details>

## Inject dependencies

<details>
<summary> Details (Click to expand) </summary>
<br>

Each sync manager is initialized with a `Services` protocol that combines remote and local services. This is a public protocol you can use to create your own dependency.

`Mock` implementations are included for SwiftUI previews and testing.

```swift
// Mock with blank data
let services = MockDMDocumentServices<UserModel>()

// Mock with custom data
let user = UserModel(id: "123", name: "John")
let services = MockDMDocumentServices(document: user)
```

Other services are not directly included, so that the developer can pick-and-choose which dependencies to add to the project.

You can create your own services by conforming to the protocols:

```swift
public protocol DMDocumentServices {
    associatedtype T: DMProtocol
    var remote: any RemoteDocumentService<T> { get }
    var local: any LocalDocumentPersistence<T> { get }
}

public protocol DMCollectionServices {
    associatedtype T: DMProtocol
    var remote: any RemoteCollectionService<T> { get }
    var local: any LocalCollectionPersistence<T> { get }
}
```

</details>

## Document Management

<details>
<summary> Details (Click to expand) </summary>
<br>

### Configuration

```swift
let config = DataManagerSyncConfiguration(
    managerKey: "user",              // Unique identifier for this manager
    enablePendingWrites: true        // Queue failed operations for retry
)

// Async configuration (no pending writes)
let asyncConfig = DataManagerAsyncConfiguration(
    managerKey: "user"
)
```

**⚠️ Important: Key Sanitization**

All configuration keys (`managerKey`) are validated and must:
- Contain only alphanumeric characters, underscores, and hyphens
- Not contain periods (`.`), slashes (`/`), or special characters
- Be 1-512 characters long
- Examples: `"user"`, `"user_profile"`, `"user-settings"` ✅
- Invalid: `"user.profile"`, `"user/settings"` ❌

### Log In / Log Out (Sync Managers)

```swift
// Log in (starts remote listener for real-time updates)
try await documentManager.logIn("document_123")

// Log out (stops listeners and clears local data)
documentManager.logOut()
```

### CRUD Operations

```swift
// Get document
let document = documentManager.getDocument()              // Sync - from cache
let document = try await documentManager.getDocumentAsync() // Async - from remote

// Save document
try await documentManager.saveDocument(document)

// Update document with partial data
try await documentManager.updateDocument(data: [
    "name": "John Doe",
    "age": 30,
    "verified": true
])

// Delete document
try await documentManager.deleteDocument()
```

### Access Current Document (Sync Managers)

```swift
// Observable property for SwiftUI
let document = documentManager.currentDocument

// Get or throw if not available
let document = try documentManager.getDocumentOrThrow()

// Get document ID
let id = try documentManager.getDocumentId()
```

### Pending Writes (Sync Managers Only)

Failed operations are automatically queued when `enablePendingWrites = true`:

```swift
// Operations that fail will be added to pending writes queue
try await documentManager.updateDocument(data: ["status": "active"])

// Pending writes sync automatically on next successful connection
// Manual sync happens during logIn()
```

</details>

## Collection Management

<details>
<summary> Details (Click to expand) </summary>
<br>

### Configuration

Same configuration as Document Management:

```swift
let config = DataManagerSyncConfiguration(
    managerKey: "products",
    enablePendingWrites: true
)
```

### Log In / Log Out (Sync Managers)

```swift
// Log in (bulk loads collection then streams updates)
await collectionManager.logIn()

// Log out (stops listeners and clears local data)
await collectionManager.logOut()
```

### Collection Operations

```swift
// Get collection
let items = collectionManager.getCollection()              // Sync - from cache
let items = try await collectionManager.getCollectionAsync() // Async - from remote

// Get single document
let item = collectionManager.getDocument(id: "item_123")
let item = try await collectionManager.getDocumentAsync(id: "item_123")

// Save document to collection
try await collectionManager.saveDocument(document)

// Update document in collection
try await collectionManager.updateDocument(id: "item_123", data: ["price": 99.99])

// Delete document from collection
try await collectionManager.deleteDocument(id: "item_123")
```

### Query Builder

```swift
// Build complex queries
let query = QueryBuilder()
    .whereField("category", isEqualTo: "electronics")
    .whereField("price", isLessThan: 1000)
    .orderBy(field: "price", descending: true)
    .limit(10)

let results = try await collectionManager.getDocuments(query: query)
```

### Access Current Collection (Sync Managers)

```swift
// Observable property for SwiftUI
let collection = collectionManager.currentCollection

// Get collection synchronously
let collection = collectionManager.getCollection()

// Check if collection contains document
let hasDocument = collectionManager.containsDocument(id: "item_123")
```

### Streaming Pattern (Sync Managers)

CollectionManagerSync follows the "hybrid sync" pattern:
1. Bulk loads all documents on `logIn()`
2. Streams individual document updates/deletions
3. Maintains local cache for offline access

</details>

## DMProtocol Requirements

<details>
<summary> Details (Click to expand) </summary>
<br>

All managed types must conform to `DMProtocol`:

```swift
public protocol DMProtocol: Codable, Sendable, StringIdentifiable {
    var eventParameters: [String: Any] { get }
    static var mocks: [Self] { get }
}

// Example implementation
struct UserModel: DMProtocol {
    let id: String  // Required by StringIdentifiable
    var name: String
    var email: String
    var age: Int

    var eventParameters: [String: Any] {
        ["user_name": name, "user_age": age]
    }

    static var mocks: [Self] {
        [
            UserModel(id: "1", name: "John", email: "john@example.com", age: 30),
            UserModel(id: "2", name: "Jane", email: "jane@example.com", age: 25)
        ]
    }
}
```

</details>

## Local Persistence

<details>
<summary> Details (Click to expand) </summary>
<br>

### FileManager Persistence (Included)

Simple JSON-based persistence using FileManager:

```swift
let persistence = FileManagerDocumentPersistence<UserModel>()
```

### SwiftData Persistence (Included for Collections)

SwiftData-backed persistence for collections:

```swift
let persistence = SwiftDataCollectionPersistence<ProductModel>(managerKey: "products")
```

### Custom Persistence

Implement the protocols for custom persistence:

```swift
public protocol LocalDocumentPersistence<T>: Sendable {
    func saveDocument(managerKey: String, _ document: T?) throws
    func getDocument(managerKey: String) throws -> T?
    func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws
    func getPendingWrites(managerKey: String) throws -> [PendingWrite]
    // ...
}
```

**Note**: Following SwiftfulGamification patterns, persistence methods accept `managerKey` as a parameter rather than storing it.

</details>

## Analytics Integration

<details>
<summary> Details (Click to expand) </summary>
<br>

All managers support optional analytics logging:

```swift
// Create logger (see SwiftfulLogging package)
let logger = LogManager(services: [
    FirebaseAnalyticsService(),
    MixpanelService()
])

// Inject into managers
let documentManager = DocumentManagerSync(
    services: services,
    configuration: config,
    logger: logger
)
```

### Tracked Events

**DocumentManagerSync/CollectionManagerSync**:
- `{key}_listener_start/success/fail/retrying`
- `{key}_save_start/success/fail`
- `{key}_update_start/success/fail`
- `{key}_delete_start/success/fail`
- `{key}_documentUpdated/documentDeleted`
- `{key}_pendingWriteAdded/pendingWritesCleared`
- `{key}_syncPendingWrites_start/complete`
- `{key}_bulkLoad_start/success/fail` (CollectionManagerSync only)

**DocumentManagerAsync/CollectionManagerAsync**:
- `{key}_get_start/success/fail`
- `{key}_save_start/success/fail`
- `{key}_update_start/success/fail`
- `{key}_delete_start/success/fail`

### Event Parameters

All events include relevant parameters:

```swift
"document_id": "user_123"
"error_description": "Network unavailable"
"pending_write_count": 3
"retry_count": 2
"delay_seconds": 4.0
```

</details>

## Mock Factories

<details>
<summary> Details (Click to expand) </summary>
<br>

All configurations and services include mock factory methods for testing:

### Configurations

```swift
// Default mock configuration
DataManagerSyncConfiguration.mock()

// Mock without pending writes
DataManagerSyncConfiguration.mockNoPendingWrites()

// Async configuration mock
DataManagerAsyncConfiguration.mock()
```

### Services

```swift
// Mock document services
let services = MockDMDocumentServices(document: UserModel.mock)

// Mock collection services
let services = MockDMCollectionServices(collection: ProductModel.mocks)

// Mock remote services
let remote = MockRemoteDocumentService(document: UserModel.mock)
let remote = MockRemoteCollectionService(collection: ProductModel.mocks)

// Mock local persistence
let local = MockLocalDocumentPersistence(document: UserModel.mock)
let local = MockLocalCollectionPersistence(collection: ProductModel.mocks)
```

</details>

## Architecture

<details>
<summary> Details (Click to expand) </summary>
<br>

SwiftfulDataManagers follows the **SwiftfulThinking Provider Pattern**:

1. **Base Package** (this package):
   - Zero external dependencies (except IdentifiableByString)
   - Defines all protocols and models
   - Includes Mock implementations
   - All types are `Codable` and `Sendable`

2. **Implementation Packages** (separate SPM):
   - SwiftfulDataManagersFirebase: Firebase implementation
   - Implements service protocols
   - Handles provider-specific logic

3. **Manager Classes**:
   - `@MainActor` for UI thread safety
   - `@Observable` for SwiftUI integration
   - Dependency injection via protocols
   - Optional logger for analytics
   - Comprehensive event tracking

### Key Features

- **Swift 6 concurrency**: Full async/await support
- **Thread safety**: `@MainActor` isolation, `Sendable` conformance
- **SwiftUI ready**: `@Observable` support
- **Offline first**: Local persistence with remote sync (Sync managers)
- **Real-time sync**: AsyncStream-based listeners
- **Type-safe**: Protocol-based architecture
- **Testable**: Mock implementations included
- **Listener retry**: Exponential backoff for failed connections

### Manager Types

```
┌─────────────────────────┬────────────────────────┐
│    Sync Managers        │    Async Managers      │
├─────────────────────────┼────────────────────────┤
│ ✓ Real-time listeners   │ ✗ No listeners         │
│ ✓ Local persistence     │ ✗ No local cache       │
│ ✓ Offline support       │ ✗ Online only          │
│ ✓ Pending writes queue  │ ✗ No queue             │
│ ✓ Observable properties │ ✗ Async methods only   │
└─────────────────────────┴────────────────────────┘
```

</details>

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/SwiftfulThinking/SwiftfulDataManagers.git", branch: "main")
]
```

## Contributing

Community contributions are encouraged! Please ensure that your code adheres to the project's existing coding style and structure.

- [Open an issue](https://github.com/SwiftfulThinking/SwiftfulDataManagers/issues) for issues with the existing codebase.
- [Open a discussion](https://github.com/SwiftfulThinking/SwiftfulDataManagers/discussions) for new feature requests.
- [Submit a pull request](https://github.com/SwiftfulThinking/SwiftfulDataManagers/pulls) when the feature is ready.

## Related Packages

- [SwiftfulDataManagersFirebase](https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase) - Firebase implementation
- [SwiftfulGamification](https://github.com/SwiftfulThinking/SwiftfulGamification) - Reference implementation patterns
- [SwiftfulLogging](https://github.com/SwiftfulThinking/SwiftfulLogging) - Analytics logging
- [SwiftfulStarterProject](https://github.com/SwiftfulThinking/SwiftfulStarterProject) - Full integration example

## License

MIT License. See LICENSE file for details.