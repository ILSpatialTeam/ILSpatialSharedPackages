import Foundation

// MARK: - Endpoint

public enum HealthCheckEndpoint: Endpoint {
    case ping
    case status

    public var path: String {
        switch self {
        case .ping:   "/health/ping"
        case .status: "/health/status"
        }
    }

    public var method: HTTPMethod { .get }
}

// MARK: - Response Models

public struct PingResponse: Decodable, Sendable, Equatable {
    public let message: String
}

public struct StatusResponse: Decodable, Sendable, Equatable {
    public let status: String
    public let version: String?
    public let uptime: TimeInterval?
}

// MARK: - Protocol (for mocking in app tests)

public protocol HealthCheckServiceProtocol: Sendable {
    func ping() async throws -> PingResponse
    func status() async throws -> StatusResponse
}

// MARK: - Concrete Service

public final class HealthCheckService: ServiceProtocol, HealthCheckServiceProtocol {
    public let client: any NetworkClientProtocol

    public init(client: any NetworkClientProtocol) {
        self.client = client
    }

    public func ping() async throws -> PingResponse {
        try await client.request(
            HealthCheckEndpoint.ping,
            as: PingResponse.self
        ).data
    }

    public func status() async throws -> StatusResponse {
        try await client.request(
            HealthCheckEndpoint.status,
            as: StatusResponse.self
        ).data
    }
}
