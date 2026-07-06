import Foundation

/// Describes a single API endpoint.
///
/// Conformers declare *what* to call; `NetworkClient` handles *how*.
///
/// ```swift
/// enum UserEndpoint: Endpoint {
///     case profile(id: String)
///     case updateName(id: String, body: UpdateNameBody)
///
///     var path: String {
///         switch self {
///         case .profile(let id):  "/users/\(id)"
///         case .updateName(let id, _): "/users/\(id)/name"
///         }
///     }
///     var method: HTTPMethod {
///         switch self {
///         case .profile: .get
///         case .updateName: .put
///         }
///     }
///     var body: Encodable? {
///         switch self {
///         case .profile: nil
///         case .updateName(_, let body): body
///         }
///     }
/// }
/// ```
public protocol Endpoint: Sendable {

    /// Relative path appended to the base URL (e.g. `"/users/123"`).
    var path: String { get }

    /// HTTP method.
    var method: HTTPMethod { get }

    /// Query parameters appended to the URL.
    var queryItems: [URLQueryItem]? { get }

    /// HTTP headers merged on top of `NetworkConfiguration.defaultHeaders`.
    var headers: [String: String]? { get }

    /// Encodable body. `nil` for GET / DELETE requests.
    var body: (any Encodable & Sendable)? { get }

    /// Override the default `JSONEncoder` for this endpoint.
    var encoder: JSONEncoder? { get }

    /// Override the timeout for this endpoint (seconds).
    var timeoutInterval: TimeInterval? { get }

    /// Cache policy override for this endpoint.
    var cachePolicy: URLRequest.CachePolicy? { get }
}

// MARK: - Sensible Defaults

public extension Endpoint {
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String: String]? { nil }
    var body: (any Encodable & Sendable)? { nil }
    var encoder: JSONEncoder? { nil }
    var timeoutInterval: TimeInterval? { nil }
    var cachePolicy: URLRequest.CachePolicy? { nil }
}
