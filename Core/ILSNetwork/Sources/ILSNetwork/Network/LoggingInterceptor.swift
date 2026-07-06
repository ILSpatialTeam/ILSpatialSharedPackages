import Foundation
import os.log

/// Logs request/response details to `os.log`.
///
/// Disabled by default in release builds.
public struct LoggingInterceptor: RequestInterceptor {

    private let logger: Logger
    private let isEnabled: Bool

    public init(
        subsystem: String = "CoreNetwork",
        category: String = "HTTP",
        isEnabled: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.isEnabled = isEnabled
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        guard isEnabled else { return request }
        logger.debug("➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        return request
    }

    public func intercept(
        _ response: RawResponse,
        for request: URLRequest
    ) async throws -> RawResponse {
        guard isEnabled else { return response }
        logger.debug(
            "⬅️ \(response.statusCode) \(request.url?.absoluteString ?? "?") (\(response.data.count) bytes)"
        )
        return response
    }
}
