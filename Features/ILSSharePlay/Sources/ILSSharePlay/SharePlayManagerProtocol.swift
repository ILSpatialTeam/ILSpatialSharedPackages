import Foundation

/// A generic base protocol for SharePlay managers, living in ILSFoundation
/// so future features (games, media) can share the same base interface.
public protocol SharePlayManagerProtocol: AnyObject {
    var isSharing: Bool { get }
    var localParticipantID: UUID { get }
    func startListening() async
    func stopSharing()
}
