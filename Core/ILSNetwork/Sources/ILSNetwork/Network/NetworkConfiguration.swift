import Foundation

/// Immutable configuration object supplied to `NetworkClient`.
public struct NetworkConfiguration: Sendable {

    public let baseURL: URL
    public let defaultHeaders: [String: String]
    public let timeoutInterval: TimeInterval
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder

    public init(
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 30,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.encoder = encoder
        self.decoder = decoder
    }
}

// MARK: - Convenience Builder

public extension NetworkConfiguration {

    /// Merges `Content-Type: application/json` and `Accept: application/json`
    /// into `defaultHeaders` automatically.
    static func json(
        baseURL: URL,
        additionalHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 30,
        encoder: JSONEncoder = .defaultEncoder,
        decoder: JSONDecoder = .defaultDecoder
    ) -> NetworkConfiguration {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        headers.merge(additionalHeaders) { _, new in new }
        return NetworkConfiguration(
            baseURL: baseURL,
            defaultHeaders: headers,
            timeoutInterval: timeoutInterval,
            encoder: encoder,
            decoder: decoder
        )
    }
}
