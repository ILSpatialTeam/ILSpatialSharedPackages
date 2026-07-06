import Foundation

/// Base protocol for all network services.
///
/// Services encapsulate a group of related endpoints and expose
/// domain-level async methods. They depend on `NetworkClientProtocol`,
/// never on `URLSession` directly.
///
/// ```swift
/// final class UserService: ServiceProtocol {
///     let client: NetworkClientProtocol
///     init(client: NetworkClientProtocol) { self.client = client }
///
///     func fetchProfile(id: String) async throws -> User {
///         try await client.request(
///             UserEndpoint.profile(id: id),
///             as: User.self
///         ).data
///     }
/// }
/// ```
public protocol ServiceProtocol: Sendable {
    var client: any NetworkClientProtocol { get }
    init(client: any NetworkClientProtocol)
}
