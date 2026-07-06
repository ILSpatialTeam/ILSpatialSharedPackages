import Foundation

/// Abstracts `URLSession` so the network layer can be tested with a mock.
///
/// The production conformance is a thin wrapper on `URLSession.shared`
/// (or any configured session). Tests inject `MockNetworkSession`.
public protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - Production Conformance

extension URLSession: NetworkSession {}
