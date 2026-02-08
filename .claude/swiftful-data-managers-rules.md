# SwiftfulDataManagers

Real-time data sync engines for Swift. Manages documents and collections with optional local persistence, pending writes, and streaming updates. Built for composition — not subclassing.

## When to Use

This package is a **convenience layer** for managers that work with a remote database document or collection. It is NOT required — managers can implement their own data fetching and caching logic. Use it when you want persistence, pending writes, real-time listeners, or the convenience read/write APIs out of the box.

IMPORTANT: This package belongs ONLY in the **manager layer** of the application. Not all managers need it. Only use it when a manager's primary job is syncing data from a remote document or collection.

## Engines

- `DocumentSyncEngine<T>` — single document real-time sync with optional FileManager persistence
- `CollectionSyncEngine<T>` — collection real-time sync with optional SwiftData persistence
- Both are `@Observable` `final class` — designed for composition, not subclassing
- Models must conform to `DataSyncModelProtocol` (`StringIdentifiable & Codable & Sendable`)

```swift
// Single document
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
    managerKey: "user",
    enableLocalPersistence: true,
    logger: logManager
)

// Collection
let productsSyncEngine = CollectionSyncEngine<Product>(
    remote: FirebaseRemoteCollectionService(collectionPath: { "products" }),
    managerKey: "products",
    enableLocalPersistence: true,
    logger: logManager
)
```

## Naming Convention

NEVER name an engine instance just `engine`. ALWAYS use a descriptive name that reflects what data it manages:

- `userSyncEngine`, `settingsSyncEngine`, `subscriptionSyncEngine` — for `DocumentSyncEngine`
- `productsSyncEngine`, `watchlistSyncEngine`, `messagesSyncEngine` — for `CollectionSyncEngine`

This is especially important when a manager owns multiple engines — generic names like `engine` or `engine1` make code unreadable.

## DocumentSyncEngine API

```swift
// Lifecycle
try await userSyncEngine.startListening(documentId: "user_123")
userSyncEngine.stopListening()
userSyncEngine.stopListening(clearCaches: false)

// Read — sync (requires startListening() or local persistence, otherwise returns nil)
userSyncEngine.currentDocument           // Observable property
userSyncEngine.getDocument()
try userSyncEngine.getDocumentOrThrow()

// Read — async
try await userSyncEngine.getDocumentAsync()                              // cached or fetch
try await userSyncEngine.getDocumentAsync(behavior: .alwaysFetch)        // always fetch
try await userSyncEngine.getDocumentAsync(id: "user_456")                // by ID, no listener needed
try userSyncEngine.getDocumentId()                                       // get stored document ID

// Write
try await userSyncEngine.saveDocument(user)
try await userSyncEngine.updateDocument(data: ["name": "John"])
try await userSyncEngine.updateDocument(id: "user_123", data: ["name": "John"])  // by ID, no listener needed
try await userSyncEngine.deleteDocument()
try await userSyncEngine.deleteDocument(id: "user_123")
```

## CollectionSyncEngine API

```swift
// Lifecycle — hybrid sync: bulk load + stream changes
await productsSyncEngine.startListening()
productsSyncEngine.stopListening()
productsSyncEngine.stopListening(clearCaches: false)

// Read — sync (requires startListening() or local persistence, otherwise returns empty/nil)
productsSyncEngine.currentCollection         // Observable property
productsSyncEngine.getCollection()
productsSyncEngine.getDocument(id: "product_123")
productsSyncEngine.getDocuments(where: { $0.price < 10 })

// Read — async
try await productsSyncEngine.getCollectionAsync()
try await productsSyncEngine.getCollectionAsync(behavior: .alwaysFetch)
try await productsSyncEngine.getDocumentAsync(id: "product_123")
try await productsSyncEngine.getDocumentsAsync(where: { $0.price < 10 })
try await productsSyncEngine.getDocumentsAsync(buildQuery: { query in
    query.where("category", isEqualTo: "electronics")
})

// Stream
let stream = productsSyncEngine.streamDocument(id: "product_123")

// Write
try await productsSyncEngine.saveDocument(product)
try await productsSyncEngine.updateDocument(id: "product_123", data: ["price": 29.99])
try await productsSyncEngine.deleteDocument(id: "product_123")
```

## Composition Pattern

IMPORTANT: ALWAYS wrap engines in your own manager classes. Never expose engines directly to views. This lets you add domain logic, combine multiple engines, and control the public API.

Engines are created in the **Dependencies** layer and **injected** into managers. Managers never create their own engines — this keeps them testable and environment-agnostic.

### Dependencies (creates engines)

```swift
// Production
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
    managerKey: "user",
    enableLocalPersistence: true,
    logger: logManager
)
let userManager = UserManager(userSyncEngine: userSyncEngine)

// Mock
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: MockRemoteDocumentService(),
    managerKey: "user",
    enableLocalPersistence: false
)
let userManager = UserManager(userSyncEngine: userSyncEngine)
```

### Manager (receives engine via injection)

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
}
```

### Multiple engines in one manager

A single manager can own multiple engines, each with its own remote source, `managerKey`, and `enableLocalPersistence` setting. All engines are injected:

```swift
@MainActor
@Observable
class ContentManager {
    private let moviesSyncEngine: CollectionSyncEngine<Movie>
    private let watchlistSyncEngine: CollectionSyncEngine<WatchlistItem>

    var movies: [Movie] { moviesSyncEngine.currentCollection }
    var watchlist: [WatchlistItem] { watchlistSyncEngine.currentCollection }

    init(
        moviesSyncEngine: CollectionSyncEngine<Movie>,
        watchlistSyncEngine: CollectionSyncEngine<WatchlistItem>
    ) {
        self.moviesSyncEngine = moviesSyncEngine
        self.watchlistSyncEngine = watchlistSyncEngine
    }
}
```

### Dynamic collection paths

For user-scoped collections where the remote path changes (e.g., account switch), use a closure for the collection path when creating the engine in Dependencies:

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

// On sign-in → startListening() resolves to new user's path
// On sign-out → stopListening() clears old data
// On new sign-in → startListening() resolves to new user's path
```

## Document vs Collection Decision Guide

- **DocumentSyncEngine:** The remote location points to one specific document identified by an ID — user profile, app settings, subscription status, user preferences
- **CollectionSyncEngine:** The remote location points to a full collection of documents — products, watchlist items, notifications
- If the data is "one thing per user," use Document. If it's "many things," use Collection.

WARNING: `CollectionSyncEngine.startListening()` syncs the **entire collection** — it bulk loads all documents and then streams every change. If a collection may contain thousands of documents (e.g., all users, all orders globally), do NOT attach a listener to the full collection. `CollectionSyncEngine` is intended for bounded, user-scoped collections (e.g., a user's watchlist, a user's notifications) where the total document count is manageable. For large collections, use `getDocumentsAsync(buildQuery:)` to query specific subsets from remote without syncing everything.

## Local Persistence

`enableLocalPersistence` controls all local behavior: caching, pending writes, and offline recovery.

- **DocumentSyncEngine** persists via FileManager (JSON files) — document, document ID, and pending writes
- **CollectionSyncEngine** persists via SwiftData (`ModelContainer`) — documents + pending writes (JSON via FileManager)
- When `enableLocalPersistence: true` and a write fails, the write is queued and retried on next `startListening()`
- For documents: pending writes merge into a single write. For collections: tracked per document ID
- Listener retry uses exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max)

## Threading

- Both engines are `@MainActor` — all public API calls and property access happen on the main thread
- Listener callbacks and observable property updates are delivered on the main thread (safe for SwiftUI)
- **Exception:** `SwiftDataCollectionPersistence.saveCollection()` is `nonisolated` and runs on a background thread using a background `ModelContext` for performance — this avoids blocking the main thread when persisting large collections to disk
- Remote service calls (`getDocument`, `getCollection`, `saveDocument`, etc.) are `async` and run on whatever thread the remote implementation uses — the engines `await` the result and resume on `@MainActor`

## Integration

Conform your logger to `DataSyncLogger` to receive internal engine events:

```swift
extension YourLogManager: @retroactive DataSyncLogger {
    public func trackEvent(event: any DataSyncLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type)
    }
    public func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        // forward to your analytics
    }
}
```

## Mocks

Mock engines are created in Dependencies using `MockRemoteDocumentService` or `MockRemoteCollectionService` and injected into managers the same way as production engines.

```swift
// In Dependencies — mock configuration
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: MockRemoteDocumentService(),
    managerKey: "user",
    enableLocalPersistence: false
)

// With pre-populated data
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: MockRemoteDocumentService(document: UserModel.mock),
    managerKey: "user",
    enableLocalPersistence: false
)

// Mock collection
let productsSyncEngine = CollectionSyncEngine<Product>(
    remote: MockRemoteCollectionService(collection: Product.mocks),
    managerKey: "products",
    enableLocalPersistence: false
)

// Inject into managers the same way
let userManager = UserManager(userSyncEngine: userSyncEngine)
```

Mock init signatures: `MockRemoteDocumentService(document: T? = nil)`, `MockRemoteCollectionService(collection: [T] = [])`. The `.mock` / `.mocks` properties are NOT part of `DataSyncModelProtocol` — you must define them on your own models.

ALWAYS set `enableLocalPersistence: false` in mocks and previews.

## Usage Guidelines

### stopListening behavior

- `stopListening()` clears all caches (memory + disk) by default
- `stopListening(clearCaches: false)` only cancels the listener — cached data stays in memory and on disk
- Use `clearCaches: false` when you want to keep showing stale data while temporarily disconnected

### Standalone operations without a listener

- `updateDocument(id:data:)`, `deleteDocument(id:)`, and `getDocumentAsync(id:)` on `DocumentSyncEngine` accept an explicit `id` — no listener needed
- On `CollectionSyncEngine`, `id` is always required for write operations — no listener needed
- Use this for one-off writes to documents you don't need to actively listen to

### VIPER Integration

IMPORTANT: Views and Presenters should NEVER import or reference `SwiftfulDataManagers` directly. This package belongs exclusively in the manager layer of the application. Views and Presenters interact with managers through Interactor protocols — they should have no awareness that sync engines exist.

In a VIPER architecture, engines live inside manager classes, managers live inside the Interactor, and Presenters call Interactor methods — never managers directly.

```swift
// Manager — receives engine via injection, adds domain logic
@MainActor @Observable
class UserManager {
    private let userSyncEngine: DocumentSyncEngine<UserModel>
    var currentUser: UserModel? { userSyncEngine.currentDocument }

    init(userSyncEngine: DocumentSyncEngine<UserModel>) {
        self.userSyncEngine = userSyncEngine
    }

    func signIn(auth: UserAuthInfo, isNewUser: Bool) async throws {
        let user = UserModel(auth: auth, creationVersion: isNewUser ? Utilities.appVersion : nil)
        try await userSyncEngine.saveDocument(user)
        try await userSyncEngine.startListening(documentId: auth.uid)
    }

    func signOut() {
        userSyncEngine.stopListening()
    }
}

// Interactor — owns all managers, exposes methods to Presenters
@MainActor
struct CoreInteractor {
    let userManager: UserManager
    let contentManager: ContentManager

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
        try await userManager.signIn(auth: user, isNewUser: isNewUser)
        await contentManager.startListening()
    }

    func signOut() {
        userManager.signOut()
        contentManager.stopListening()
    }
}

// Presenter — calls interactor, never managers directly
func onSignInApplePressed() {
    Task {
        let result = try await interactor.signInApple()
        try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)
    }
}

// View — observes presenter, never interactor or managers directly
var body: some View {
    if let user = presenter.currentUser {
        Text(user.name)
    }
}
```
