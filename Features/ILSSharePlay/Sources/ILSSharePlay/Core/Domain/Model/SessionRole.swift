import Foundation

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
