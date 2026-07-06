import Foundation

/// Intercepts outgoing requests and incoming responses.
///
/// Use cases: auth token injection, logging, analytics, retry logic.
///
/// ```swift
/// struct AuthInterceptor: RequestInterceptor {
///     let tokenProvider: () async -> String
///
///     func intercept(_ request: URLRequest) async throws -> URLRequest {
///         var r = request
///         let token = await tokenProvider()
///         r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
///         return r
///     }
/// }
/// ```
public protocol RequestInterceptor: Sendable {

    /// Modify the request before it leaves the device.
    func intercept(_ request: URLRequest) async throws -> URLRequest

    /// Inspect or transform the raw response before decoding.
    func intercept(
        _ response: RawResponse,
        for request: URLRequest
    ) async throws -> RawResponse

    /// Called when a request fails. Return `true` to retry.
    func shouldRetry(
        _ request: URLRequest,
        dueTo error: NetworkError,
        attempt: Int
    ) async -> Bool
}

// MARK: - Defaults (all optional)

public extension RequestInterceptor {

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func intercept(
        _ response: RawResponse,
        for request: URLRequest
    ) async throws -> RawResponse {
        response
    }

    func shouldRetry(
        _ request: URLRequest,
        dueTo error: NetworkError,
        attempt: Int
    ) async -> Bool {
        false
    }
}
