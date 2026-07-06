# CoreNetwork

A protocol-based, async/await networking layer for Apple platforms. Zero third-party dependencies — built entirely on native `URLSession`.

## Platforms

iOS 15+ · macOS 12+ · visionOS 1+ · watchOS 8+ · tvOS 15+

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/CoreNetwork.git", from: "1.0.0")
]
```

## Quick Start

### 1. Define Your Endpoints

```swift
import CoreNetwork

enum UserEndpoint: Endpoint {
    case list
    case detail(id: String)
    case create(body: CreateUserRequest)

    var path: String {
        switch self {
        case .list:             "/users"
        case .detail(let id):   "/users/\(id)"
        case .create:           "/users"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail: .get
        case .create:        .post
        }
    }

    var body: (any Encodable & Sendable)? {
        switch self {
        case .create(let body): body
        default: nil
        }
    }
}
```

### 2. Create a Service

```swift
protocol UserServiceProtocol: Sendable {
    func fetchUsers() async throws -> [User]
    func fetchUser(id: String) async throws -> User
}

final class UserService: ServiceProtocol, UserServiceProtocol {
    let client: any NetworkClientProtocol
    init(client: any NetworkClientProtocol) { self.client = client }

    func fetchUsers() async throws -> [User] {
        try await client.request(UserEndpoint.list, as: [User].self).data
    }

    func fetchUser(id: String) async throws -> User {
        try await client.request(UserEndpoint.detail(id: id), as: User.self).data
    }
}
```

### 3. Wire It Up

```swift
let config = NetworkConfiguration.json(
    baseURL: URL(string: "https://api.example.com/v1")!,
    additionalHeaders: ["X-API-Version": "2"]
)

let client = NetworkClient(
    configuration: config,
    interceptors: [
        AuthInterceptor { await TokenStore.shared.accessToken },
        LoggingInterceptor()
    ],
    maxRetries: 2
)

let userService = UserService(client: client)
let users = try await userService.fetchUsers()
```

### 4. Test With Mocks

```swift
final class UserServiceTests: XCTestCase {
    func test_fetchUsers_returnsDecodedList() async throws {
        let mockClient = MockNetworkClient()
        mockClient.requestHandler = { _ in
            [User(id: "1", name: "Test")]
        }

        let service = UserService(client: mockClient)
        let users = try await service.fetchUsers()

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Test")
    }
}
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  App Target (visionOS / iOS / macOS)            │
│  ┌───────────────────────────────────────────┐  │
│  │  App-Specific Services                    │  │
│  │  ArcheryService · MoleCraftService · ...  │  │
│  └──────────────────┬────────────────────────┘  │
│                     │ depends on                │
├─────────────────────┼───────────────────────────┤
│  CoreNetwork SPM    │                           │
│  ┌──────────────────┴────────────────────────┐  │
│  │  Service Layer (shared)                   │  │
│  │  AuthService · HealthCheckService         │  │
│  ├───────────────────────────────────────────┤  │
│  │  Network Layer (generic)                  │  │
│  │  NetworkClient ← NetworkSession(URLSession)│  │
│  │  RequestBuilder · Interceptors            │  │
│  │  Endpoint · NetworkError · NetworkResponse│  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```
