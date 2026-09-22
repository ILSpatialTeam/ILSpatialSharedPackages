//
//  CockpitSpatialTemplate.swift
//  ILSSharePlay
//
//  Created by Tafani Rabbani on 18/09/26.
//
import GroupActivities

/// A custom spatial template that positions SharePlay personas in the cockpit.
///
/// **How it works**: On visionOS 1.x, the OS assigns participants to seats based
/// on the order they joined. To ensure everyone gets the correct physical seat,
/// this template dynamically orders the seat array to match the roles of the
/// participants exactly as they appear in the join order.
struct CockpitSpatialTemplate: SpatialTemplate {
    
    /// The current list of participants
    let participants: [CockpitParticipant]
    
    /// The order in which participants joined (and thus the order the OS assigns seats)
    let joinOrder: [String]
    
    var elements: [any SpatialTemplateElement] {
        var seats: [any SpatialTemplateElement] = []
        
        // Define the physical coordinates for each role
        func position(for role: SessionRole) -> SpatialTemplateElementPosition {
            let x: Double = (role == .copilot || role == .instructor2) ? 0.55 : -0.55
            let z: Double = (role == .instructor1 || role == .instructor2) ? 1.0 : 0.0
            return .app.offsetBy(x: x, z: z)
        }
        
        func direction(for role: SessionRole) -> SpatialTemplateElementDirection {
            let x: Double = (role == .copilot || role == .instructor2) ? 0.55 : -0.55
            let z: Double = (role == .instructor1 || role == .instructor2) ? 1.0 : 0.0
            return .lookingAt(.app.offsetBy(x: x, z: z - 10.0))
        }
        
        // 1. Build seats for active participants in their exact join order
        for (index, pid) in joinOrder.enumerated() {
            guard let participant = participants.first(where: { $0.id == pid }) else { continue }
            let pos = position(for: participant.role)
            print("[SpatialTemplate] Building seat for Join Index \(index): Participant \(participant.role.rawValue)")
            seats.append(.seat(
                position: pos,
                direction: direction(for: participant.role)
            ))
        }
        
        // 2. Pad out the remaining seats for any future joiners using unassigned roles
        let assignedRoles = Set(participants.map(\.role))
        let remainingRoles = SessionRole.allCases.filter { !assignedRoles.contains($0) }
        
        for role in remainingRoles {
            let pos = position(for: role)
            print("[SpatialTemplate] Padding unassigned seat for \(role.rawValue)")
            seats.append(.seat(
                position: pos,
                direction: direction(for: role)
            ))
        }
        
        print("[SpatialTemplate] Final built template has \(seats.count) seats.")
        return seats
    }
}
