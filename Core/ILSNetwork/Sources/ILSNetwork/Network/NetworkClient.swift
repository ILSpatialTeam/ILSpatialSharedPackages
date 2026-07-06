import Foundation

/// Protocol that any network client must conform to.
///
/// This is what services depend on — never a concrete class.
public protocol NetworkClientProtocol: Sendable {

    /// Execute an endpoint and decode the response into `T`.
    func request<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type
    ) async throws -> NetworkResponse<T>

    /// Execute an endpoint that returns no meaningful body (e.g. DELETE 204).
    func request(_ endpoint: any Endpoint) async throws -> NetworkResponse<Void>

    /// Execute an endpoint and return raw `Data` (e.g. file downloads).
    func requestData(
        _ endpoint: any Endpoint
    ) async throws -> NetworkResponse<Data>
}

// MARK: - Concrete Implementation

public final class NetworkClient: NetworkClientProtocol, Sendable {

    private let session: any NetworkSession
    private let configuration: NetworkConfiguration
    private let requestBuilder: any RequestBuilding
    private let interceptors: [any RequestInterceptor]
    private let maxRetries: Int

    public init(
        session: any NetworkSession = URLSession.shared,
        configuration: NetworkConfiguration,
        requestBuilder: any RequestBuilding = RequestBuilder(),
        interceptors: [any RequestInterceptor] = [],
        maxRetries: Int = 0
    ) {
        self.session = session
        self.configuration = configuration
        self.requestBuilder = requestBuilder
        self.interceptors = interceptors
        self.maxRetries = maxRetries
    }

    // MARK: - Decoded Response

    public func request<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type
    ) async throws -> NetworkResponse<T> {
        let raw = try await execute(endpoint)
        do {
            let decoded = try configuration.decoder.decode(T.self, from: raw.data)
            return NetworkResponse(
                data: decoded,
                statusCode: raw.statusCode,
                headers: raw.headers
            )
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Void Response

    public func request(
        _ endpoint: any Endpoint
    ) async throws -> NetworkResponse<Void> {
        let raw = try await execute(endpoint)
        return NetworkResponse(
            data: (),
            statusCode: raw.statusCode,
            headers: raw.headers
        )
    }

    // MARK: - Raw Data

    public func requestData(
        _ endpoint: any Endpoint
    ) async throws -> NetworkResponse<Data> {
        let raw = try await execute(endpoint)
        return NetworkResponse(
            data: raw.data,
            statusCode: raw.statusCode,
            headers: raw.headers
        )
    }

    // MARK: - Core Execution Pipeline

    private func execute(_ endpoint: any Endpoint) async throws -> RawResponse {
        // Build
        var urlRequest = try requestBuilder.build(
            endpoint: endpoint,
            configuration: configuration
        )

        // Pre-flight interceptors
        for interceptor in interceptors {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        // Execute with retry
        var lastError: NetworkError = .noResponse
        for attempt in 0...maxRetries {
            do {
                let raw = try await performRequest(urlRequest)

                // Post-flight interceptors
                var interceptedResponse = raw
                for interceptor in interceptors {
                    interceptedResponse = try await interceptor.intercept(
                        interceptedResponse,
                        for: urlRequest
                    )
                }

                return interceptedResponse
            } catch let error as NetworkError {
                lastError = error

                // Check retry
                guard attempt < maxRetries else { break }

                var shouldRetry = false
                for interceptor in interceptors {
                    if await interceptor.shouldRetry(
                        urlRequest,
                        dueTo: error,
                        attempt: attempt + 1
                    ) {
                        shouldRetry = true
                        break
                    }
                }

                guard shouldRetry else { break }
            }
        }

        throw lastError
    }

    private func performRequest(_ request: URLRequest) async throws -> RawResponse {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw urlError.toNetworkError()
        } catch {
            throw NetworkError.underlying(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noResponse
        }

        if let statusError = NetworkError.fromStatusCode(httpResponse.statusCode) {
            throw statusError
        }

        return RawResponse(data: data, httpResponse: httpResponse)
    }
}
