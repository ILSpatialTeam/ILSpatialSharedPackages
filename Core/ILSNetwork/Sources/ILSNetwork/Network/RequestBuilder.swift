import Foundation

/// Translates an `Endpoint` + `NetworkConfiguration` into a `URLRequest`.
///
/// Kept as a standalone protocol so building logic is testable in isolation.
public protocol RequestBuilding: Sendable {
    func build(
        endpoint: any Endpoint,
        configuration: NetworkConfiguration
    ) throws -> URLRequest
}

// MARK: - Default Implementation

public struct RequestBuilder: RequestBuilding, Sendable {

    public init() {}

    public func build(
        endpoint: any Endpoint,
        configuration: NetworkConfiguration
    ) throws -> URLRequest {

        // 1. Compose URL
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            let raw = configuration.baseURL.absoluteString + endpoint.path
            throw NetworkError.invalidURL(raw)
        }

        // 2. Build request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeoutInterval
            ?? configuration.timeoutInterval

        if let cachePolicy = endpoint.cachePolicy {
            request.cachePolicy = cachePolicy
        }

        // 3. Merge headers (endpoint wins)
        var mergedHeaders = configuration.defaultHeaders
        if let endpointHeaders = endpoint.headers {
            mergedHeaders.merge(endpointHeaders) { _, new in new }
        }
        for (key, value) in mergedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 4. Encode body
        if let body = endpoint.body {
            let encoder = endpoint.encoder ?? configuration.encoder
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw NetworkError.encodingFailed(error.localizedDescription)
            }
        }

        return request
    }
}
