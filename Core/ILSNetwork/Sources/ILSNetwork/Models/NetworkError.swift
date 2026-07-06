import Foundation

public enum NetworkError: Error, Equatable, Sendable {

    // MARK: - Request Building

    case invalidURL(String)
    case encodingFailed(String)

    // MARK: - Transport

    case noResponse
    case timeout
    case noInternetConnection
    case cancelled

    // MARK: - HTTP Status

    case unauthorized          // 401
    case forbidden             // 403
    case notFound              // 404
    case rateLimited           // 429
    case clientError(Int)      // 4xx (other)
    case serverError(Int)      // 5xx
    case unexpectedStatusCode(Int)

    // MARK: - Decoding

    case decodingFailed(String)

    // MARK: - Catch-all

    case underlying(String)
}

// MARK: - LocalizedError

extension NetworkError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .noResponse:
            return "No response received from server"
        case .timeout:
            return "Request timed out"
        case .noInternetConnection:
            return "No internet connection"
        case .cancelled:
            return "Request was cancelled"
        case .unauthorized:
            return "Unauthorized (401)"
        case .forbidden:
            return "Forbidden (403)"
        case .notFound:
            return "Resource not found (404)"
        case .rateLimited:
            return "Rate limited (429)"
        case .clientError(let code):
            return "Client error (\(code))"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code (\(code))"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        case .underlying(let message):
            return message
        }
    }
}

// MARK: - Status Code Mapping

extension NetworkError {

    public static func fromStatusCode(_ code: Int) -> NetworkError? {
        switch code {
        case 200...299:
            return nil
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        case 400...499:
            return .clientError(code)
        case 500...599:
            return .serverError(code)
        default:
            return .unexpectedStatusCode(code)
        }
    }
}
