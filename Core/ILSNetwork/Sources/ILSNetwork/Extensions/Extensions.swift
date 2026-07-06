import Foundation

// MARK: - AnyEncodable (type-eraser for Endpoint.body)

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrappedValue: any Encodable) {
        _encode = wrappedValue.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - URLError → NetworkError

extension URLError {
    func toNetworkError() -> NetworkError {
        switch code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .noInternetConnection
        case .cancelled:
            return .cancelled
        default:
            return .underlying(localizedDescription)
        }
    }
}

// MARK: - JSONEncoder / JSONDecoder Defaults

public extension JSONEncoder {
    /// snake_case keys, ISO 8601 dates, sorted keys.
    static var defaultEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    /// snake_case keys, ISO 8601 dates.
    static var defaultDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
