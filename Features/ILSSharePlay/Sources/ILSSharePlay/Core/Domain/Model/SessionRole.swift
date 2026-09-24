import Foundation
import CockpitDomain

public enum SessionRole: String, Codable, Sendable, CaseIterable, Comparable {
    case pilot
    case copilot
    case instructor1
    case instructor2

    public var displayName: String {
        switch self {
        case .pilot: return "Pilot"
        case .copilot: return "Copilot"
        case .instructor1: return "Instructor 1"
        case .instructor2: return "Instructor 2"
        }
    }

    public var cockpitRole: CockpitRole {
        switch self {
        case .pilot: return .pilot
        case .copilot: return .copilot
        case .instructor1: return .inspector1
        case .instructor2: return .inspector2
        }
    }

    public var priority: Int {
        guard let idx = Self.allCases.firstIndex(of: self) else { return 99 }
        return idx
    }

    public var authority: RoleAuthority {
        self >= .instructor1 ? .instructor : .standard
    }

    public static func < (lhs: SessionRole, rhs: SessionRole) -> Bool {
        lhs.priority < rhs.priority
    }
}

public enum RoleAuthority: Codable, Sendable {
    case standard
    case instructor
}

// Explicit lobby choices take precedence over automatic seats. UUID ordering
// breaks simultaneous claims consistently on every device, independent of Set order.
extension SessionRole {
    static func assignments(participantIDs: [String], claims: [String: SessionRole]) -> [String: SessionRole] {
        let ids = participantIDs.sorted()
        var result: [String: SessionRole] = [:]
        var remaining = allCases
        for id in ids {
            if let claim = claims[id], let index = remaining.firstIndex(of: claim) {
                result[id] = remaining.remove(at: index)
            }
        }
        for id in ids where result[id] == nil {
            guard !remaining.isEmpty else { break }
            result[id] = remaining.removeFirst()
        }
        return result
    }
}
