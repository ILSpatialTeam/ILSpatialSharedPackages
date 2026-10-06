import Foundation

public typealias HTTPHeaders = [String: String]

/// A type-safe wrapper around a decoded response and its HTTP metadata.
public struct NetworkResponse<T: Sendable>: Sendable {
    public let data: T
    public let statusCode: Int
    public let headers: HTTPHeaders

    public init(data: T, statusCode: Int, headers: HTTPHeaders = [:]) {
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
    public var headers: HTTPHeaders {
        httpResponse.allHeaderFields.reduce(into: [:]) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
    }

    public init(data: Data, httpResponse: HTTPURLResponse) {
        self.data = data
        self.httpResponse = httpResponse
    }
}
