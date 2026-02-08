# SwiftfulDataManagers

Real-time data sync engines for Swift. Manages documents and collections with optional local persistence, pending writes, and streaming updates. Built for composition — not subclassing.

Pre-built remote services:

- Mock: Included
- Firebase: https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase

## Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Add SwiftfulDataManagers to your project.

```
https://github.com/SwiftfulThinking/SwiftfulDataManagers.git
```

Import the package.

```swift
import SwiftfulDataManagers
```

Conform your models to `DataSyncModelProtocol`:

```swift
struct UserModel: DataSyncModelProtocol {
    let id: String
    var name: String
    var age: Int

    var eventParameters: [String: Any] {
        ["user_name": name, "user_age": age]
    }

    static var mocks: [Self] {
        [
            UserModel(id: "1", name: "John", age: 30),
            UserModel(id: "2", name: "Jane", age: 25)
        ]
    }
}
```

</details>

## Document vs Collection

Use `DocumentSyncEngine` when managing **a single document** (e.g., current user profile, app settings, a user's subscription). The document is identified by a specific ID.

Use `CollectionSyncEngine` when managing **a list of documents** (e.g., products, messages, watchlist items). The collection bulk loads all documents and streams individual changes.

```swift
// Single document — one user profile
let userSyncEngine = DocumentSyncEngine<UserModel>(...)

// Collection of documents — list of products
let productsSyncEngine = CollectionSyncEngine<Product>(...)
```

## DocumentSyncEngine

<details>
<summary> Details (Click to expand) </summary>
<br>

### Create

```swift
let engine = DocumentSyncEngine<UserModel>(
    remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
    managerKey: "user",
    enableLocalPersistence: true,
    logger: logManager
)
```

### Start / Stop Listening

```swift
// Start real-time sync for a document
try await engine.startListening(documentId: "user_123")

// Stop listening and clear all cached data
engine.stopListening()

// Stop listening but keep cached data in memory and on disk
engine.stopListening(clearCaches: false)
```

### Read

```swift
// Sync — from cache (requires startListening or local persistence, otherwise returns nil)
let user = engine.currentDocument
let user = engine.getDocument()
let user = try engine.getDocumentOrThrow()

// Async — returns cached if available, otherwise fetches from remote
let user = try await engine.getDocumentAsync()

// Async — always fetches from remote, ignoring cache
let user = try await engine.getDocumentAsync(behavior: .alwaysFetch)

// Async — fetch a specific document by ID (no listener needed)
let user = try await engine.getDocumentAsync(id: "user_456")

// Get stored document ID
let documentId = try engine.getDocumentId()
```

### Write

```swift
// Save a complete document
try await engine.saveDocument(user)

// Update specific fields (uses stored documentId from startListening)
try await engine.updateDocument(data: [
    "name": "John",
    "age": 30
])

// Update with explicit ID (no listener needed)
try await engine.updateDocument(id: "user_123", data: ["name": "John"])

// Delete
try await engine.deleteDocument()
try await engine.deleteDocument(id: "user_123")
```

### Observable

`DocumentSyncEngine` is `@Observable`. SwiftUI views reading `currentDocument` auto-update:

```swift
struct ProfileView: View {
    let engine: DocumentSyncEngine<UserModel>

    var body: some View {
        if let user = engine.currentDocument {
            Text(user.name)
        }
    }
}
```

</details>

## CollectionSyncEngine

<details>
<summary> Details (Click to expand) </summary>
<br>

### Create

```swift
let engine = CollectionSyncEngine<Product>(
    remote: FirebaseRemoteCollectionService(collectionPath: { "products" }),
    managerKey: "products",
    enableLocalPersistence: true,
    logger: logManager
)
```

### Start / Stop Listening

`startListening()` performs a hybrid sync: bulk loads all documents, then streams individual changes (adds, updates, deletions).

```swift
// Start real-time sync
await engine.startListening()

// Stop listening and clear all cached data
engine.stopListening()

// Stop listening but keep cached data
engine.stopListening(clearCaches: false)
```

### Read

```swift
// Sync — from cache (requires startListening or local persistence, otherwise returns empty/nil)
let products = engine.currentCollection
let products = engine.getCollection()
let product = engine.getDocument(id: "product_123")

// Async — cached or fetch
let products = try await engine.getCollectionAsync()
let product = try await engine.getDocumentAsync(id: "product_123")

// Async — always fetch from remote
let products = try await engine.getCollectionAsync(behavior: .alwaysFetch)
let product = try await engine.getDocumentAsync(id: "product_123", behavior: .alwaysFetch)

// Filter from cache (requires startListening or local persistence, otherwise returns empty)
let cheap = engine.getDocuments(where: { $0.price < 10 })

// Filter async (cached or fetch, then filter)
let cheap = try await engine.getDocumentsAsync(where: { $0.price < 10 })

// Query with QueryBuilder (always fetches from remote)
let results = try await engine.getDocumentsAsync(buildQuery: { query in
    query
        .where("category", isEqualTo: "electronics")
        .where("price", isLessThan: 1000)
})

// Stream a single document
let stream = engine.streamDocument(id: "product_123")
for try await product in stream {
    // Real-time updates
}
```

### Write

```swift
// Save a document to the collection
try await engine.saveDocument(product)

// Update specific fields on a document
try await engine.updateDocument(id: "product_123", data: ["price": 29.99])

// Delete a document
try await engine.deleteDocument(id: "product_123")
```

### Observable

```swift
struct ProductListView: View {
    let engine: CollectionSyncEngine<Product>

    var body: some View {
        ForEach(engine.currentCollection) { product in
            Text(product.name)
        }
    }
}
```

</details>

## Composition Pattern

<details>
<summary> Details (Click to expand) </summary>
<br>

Engines are designed for **composition** — wrap them in your own manager classes. This lets you add domain logic, combine multiple engines, and expose only the API your app needs.

### Single Engine

Engines are created in the Dependencies layer and injected into managers:

```swift
@MainActor
@Observable
class UserManager {
    private let userSyncEngine: DocumentSyncEngine<UserModel>

    var currentUser: UserModel? { userSyncEngine.currentDocument }

    init(userSyncEngine: DocumentSyncEngine<UserModel>) {
        self.userSyncEngine = userSyncEngine
    }

    func signIn(userId: String) async throws {
        try await userSyncEngine.startListening(documentId: userId)
    }

    func signOut() {
        userSyncEngine.stopListening()
    }

    func updateName(_ name: String) async throws {
        try await userSyncEngine.updateDocument(data: ["name": name])
    }
}
```

### Multiple Engines in One Manager

A single manager can own multiple engines, each with its own remote source, `managerKey`, and `enableLocalPersistence` setting. All engines are injected:

```swift
@MainActor
@Observable
class ContentManager {
    private let moviesSyncEngine: CollectionSyncEngine<Movie>
    private let tvShowsSyncEngine: CollectionSyncEngine<TVShow>
    private let watchlistSyncEngine: CollectionSyncEngine<WatchlistItem>

    var movies: [Movie] { moviesSyncEngine.currentCollection }
    var tvShows: [TVShow] { tvShowsSyncEngine.currentCollection }
    var watchlist: [WatchlistItem] { watchlistSyncEngine.currentCollection }

    init(
        moviesSyncEngine: CollectionSyncEngine<Movie>,
        tvShowsSyncEngine: CollectionSyncEngine<TVShow>,
        watchlistSyncEngine: CollectionSyncEngine<WatchlistItem>
    ) {
        self.moviesSyncEngine = moviesSyncEngine
        self.tvShowsSyncEngine = tvShowsSyncEngine
        self.watchlistSyncEngine = watchlistSyncEngine
    }

    func startListening() async {
        await moviesSyncEngine.startListening()
        await tvShowsSyncEngine.startListening()
        await watchlistSyncEngine.startListening()
    }

    func stopListening() {
        moviesSyncEngine.stopListening()
        tvShowsSyncEngine.stopListening()
        watchlistSyncEngine.stopListening()
    }
}
```

Each engine is fully independent — its own remote source, its own local persistence key, its own `enableLocalPersistence` setting.

### Dynamic Collection Paths

For user-scoped collections where the path changes (e.g., on account switch), use a closure for the collection path when creating the engine in Dependencies:

```swift
// In Dependencies
let watchlistSyncEngine = CollectionSyncEngine<WatchlistItem>(
    remote: FirebaseRemoteCollectionService(
        collectionPath: { [weak authManager] in
            guard let uid = authManager?.currentUserId else { return nil }
            return "users/\(uid)/watchlist"
        }
    ),
    managerKey: "watchlist"
)

// On sign-in: startListening() resolves to new user's path
// On sign-out: stopListening() clears old data
// On new sign-in: startListening() resolves to new user's path
```

</details>

## Local Persistence

<details>
<summary> Details (Click to expand) </summary>
<br>

The `enableLocalPersistence` parameter controls all local behavior: caching, pending writes, and offline recovery.

### How It Works

| | `enableLocalPersistence: true` (default) | `enableLocalPersistence: false` |
|---|---|---|
| **Cached data on launch** | Loads from disk immediately | Empty until first fetch |
| **Data saved to disk** | After every update from listener | Never |
| **Pending writes** | Failed writes queued and retried | Failed writes lost |
| **Offline recovery** | Resumes from local cache | Starts fresh |

### DocumentSyncEngine — FileManager

Single documents are persisted as JSON files via `FileManagerDocumentPersistence`. Stores three things per `managerKey`:
- The document itself (JSON)
- The document ID (so it survives app restart)
- Pending writes queue (JSON array)

### CollectionSyncEngine — SwiftData

Collections are persisted via `SwiftDataCollectionPersistence` using a `ModelContainer`. Stores:
- All documents in the collection (via `DocumentEntity` model)
- Pending writes queue (JSON file via FileManager)

Collection saves run on a background thread for performance.

### Pending Writes

When `enableLocalPersistence` is `true` and a write operation fails (e.g., network offline):

1. The failed write is saved to a local queue
2. For documents: writes merge into a single pending write (since it's one document)
3. For collections: writes are tracked per document ID (merged per document)
4. On next `startListening()`, pending writes sync automatically before attaching the listener
5. Successfully synced writes are removed from the queue; failed ones remain for next attempt

### Listener Retry

If the real-time listener fails to connect, engines retry with exponential backoff:

- Retry delays: 2s, 4s, 8s, 16s, 32s, 60s (max)
- Resets on successful connection
- Also retries on next read/write operation if listener is down

</details>

## Mocks

<details>
<summary> Details (Click to expand) </summary>
<br>

Mock implementations are included for SwiftUI previews and testing.

```swift
// Production
let engine = DocumentSyncEngine<UserModel>(
    remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
    managerKey: "user",
    logger: logManager
)

// Mock — no persistence, no real remote
let engine = DocumentSyncEngine<UserModel>(
    remote: MockRemoteDocumentService(),
    managerKey: "test",
    enableLocalPersistence: false
)

// Mock collection
let engine = CollectionSyncEngine<Product>(
    remote: MockRemoteCollectionService(collection: Product.mocks),
    managerKey: "test",
    enableLocalPersistence: false
)
```

### Available Mocks

```swift
// Remote services
MockRemoteDocumentService<T>(document: T? = nil)
MockRemoteCollectionService<T>(collection: [T] = [])

// Local persistence (for custom implementations)
MockLocalDocumentPersistence<T>(document: T? = nil)
MockLocalCollectionPersistence<T>(collection: [T] = [])
```

</details>

## Analytics

<details>
<summary> Details (Click to expand) </summary>
<br>

All engines support optional analytics via the `DataSyncLogger` protocol.

### Tracked Events

Events are prefixed with the `managerKey`:

```
{key}_listener_start / success / fail / retrying / stopped
{key}_save_start / success / fail
{key}_update_start / success / fail
{key}_delete_start / success / fail
{key}_getDocument_start / success / fail
{key}_documentUpdated / documentDeleted
{key}_pendingWriteAdded / pendingWritesCleared
{key}_syncPendingWrites_start / complete
{key}_cachesCleared
{key}_bulkLoad_start / success / fail          (CollectionSyncEngine only)
{key}_getCollection_start / success / fail      (CollectionSyncEngine only)
{key}_getDocumentsQuery_start / success / fail  (CollectionSyncEngine only)
```

### Event Parameters

```swift
"document_id": "user_123"
"error_description": "Network unavailable"
"pending_write_count": 3
"retry_count": 2
"delay_seconds": 4.0
"count": 25           // collection/bulk load count
"filter_count": 2     // query filter count
```

</details>

## Future Features

- Keychain persistence support for `DocumentSyncEngine` (secure storage for sensitive single-document data like tokens, credentials, or user secrets)

## Claude Code

This package includes a `.claude/swiftful-data-managers-rules.md` with usage guidelines and integration advice for projects using [Claude Code](https://claude.ai/claude-code).

## Platform Support

- **iOS 17.0+** / **macOS 14.0+**
- Swift 6.0+

## License

SwiftfulDataManagers is available under the MIT license.
