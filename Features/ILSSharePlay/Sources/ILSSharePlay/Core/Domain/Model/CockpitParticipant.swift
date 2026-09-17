import Foundation

public struct CockpitParticipant: Identifiable, Sendable, Equatable {
    public let id: String
    public var role: SessionRole
    public var displayName: String
    public var isLocal: Bool

    public init(id: String, role: SessionRole, displayName: String, isLocal: Bool = false) {
        self.id = id
        self.role = role
        self.displayName = displayName
        self.isLocal = isLocal
    }
}
