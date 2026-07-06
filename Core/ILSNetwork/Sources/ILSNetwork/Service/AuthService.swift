import Foundation

// MARK: - Endpoints

public enum AuthEndpoint: Endpoint {
    case login(body: LoginRequest)
    case refreshToken(body: RefreshTokenRequest)
    case logout

    public var path: String {
        switch self {
        case .login:        "/auth/login"
        case .refreshToken: "/auth/refresh"
        case .logout:       "/auth/logout"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .login, .refreshToken: .post
        case .logout:               .post
        }
    }

    public var body: (any Encodable & Sendable)? {
        switch self {
        case .login(let body):        body
        case .refreshToken(let body): body
        case .logout:                 nil
        }
    }
}

// MARK: - Request / Response Models

public struct LoginRequest: Encodable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct RefreshTokenRequest: Encodable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct AuthTokenResponse: Decodable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
}

// MARK: - Protocol

public protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthTokenResponse
    func refreshToken(_ token: String) async throws -> AuthTokenResponse
    func logout() async throws
}

// MARK: - Concrete Service

public final class AuthService: ServiceProtocol, AuthServiceProtocol {
    public let client: any NetworkClientProtocol

    public init(client: any NetworkClientProtocol) {
        self.client = client
    }

    public func login(
        email: String,
        password: String
    ) async throws -> AuthTokenResponse {
        try await client.request(
            AuthEndpoint.login(body: LoginRequest(email: email, password: password)),
            as: AuthTokenResponse.self
        ).data
    }

    public func refreshToken(_ token: String) async throws -> AuthTokenResponse {
        try await client.request(
            AuthEndpoint.refreshToken(body: RefreshTokenRequest(refreshToken: token)),
            as: AuthTokenResponse.self
        ).data
    }

    public func logout() async throws {
        _ = try await client.request(AuthEndpoint.logout)
    }
}
