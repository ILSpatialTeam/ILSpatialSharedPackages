import Foundation

/// A type-safe wrapper around a decoded response and its HTTP metadata.
public struct NetworkResponse<T: Sendable>: Sendable {
    public let data: T
    public let statusCode: Int
    public let headers: [AnyHashable: Any]

    public init(data: T, statusCode: Int, headers: [AnyHashable: Any] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// Raw response before decoding — useful for interceptors and logging.
public struct RawResponse: Sendable {
    public let data: Data
    public let httpResponse: HTTPURLResponse

    public var statusCode: Int { httpResponse.statusCode }
    public var headers: [AnyHashable: Any] { httpResponse.allHeaderFields }

    public init(data: Data, httpResponse: HTTPURLResponse) {
        self.data = data
        self.httpResponse = httpResponse
    }
}
