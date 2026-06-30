import Foundation

// Common interfaces that feature modules can depend on.

public protocol SpatialServiceProtocol {
    func start() async throws
    func stop()
}
