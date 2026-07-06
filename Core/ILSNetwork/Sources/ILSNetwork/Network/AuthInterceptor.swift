import Foundation

/// Injects a Bearer token into every outgoing request.
///
/// The `tokenProvider` closure is async so it can read from
/// Keychain, refresh an expired token, etc.
///
/// ```swift
/// let interceptor = AuthInterceptor {
///     await tokenStore.currentAccessToken()
/// }
/// ```
public struct AuthInterceptor: RequestInterceptor {

    private let tokenProvider: @Sendable () async -> String?

    public init(tokenProvider: @Sendable @escaping () async -> String?) {
        self.tokenProvider = tokenProvider
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        guard let token = await tokenProvider() else { return request }
        var modified = request
        modified.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return modified
    }
}
