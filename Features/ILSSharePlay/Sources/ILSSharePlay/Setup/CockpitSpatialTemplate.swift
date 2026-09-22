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
        
        var activeRoles = Set(participants.map(\.role))
        var remainingRoles = SessionRole.allCases.filter { !activeRoles.contains($0) }
        
        // 1. Build seats for active participants and empty slots in their exact join order
        for (index, pid) in joinOrder.enumerated() {
            if let participant = participants.first(where: { $0.id == pid }) {
                let role = participant.role
                print("[SpatialTemplate] Building seat for Join Index \(index): Participant \(role.rawValue)")
                seats.append(.seat(position: position(for: role), direction: direction(for: role)))
            } else {
                // Empty slot (someone left). Fill with an unused role to preserve indices for OS!
                if let fillerRole = remainingRoles.first {
                    remainingRoles.removeFirst()
                    print("[SpatialTemplate] Filling empty Index \(index) with padding role \(fillerRole.rawValue)")
                    seats.append(.seat(position: position(for: fillerRole), direction: direction(for: fillerRole)))
                } else {
                    print("[SpatialTemplate] Filling empty Index \(index) with dummy spectator")
                    let dummyPos: SpatialTemplateElementPosition = .app.offsetBy(x: 0, z: 2.0)
                    seats.append(.seat(position: dummyPos, direction: .lookingAt(.app.offsetBy(x: 0, z: 1.0))))
                }
            }
        }
        
        // 2. Pad out the remaining roles at the end of the array
        for role in remainingRoles {
            print("[SpatialTemplate] Padding unassigned seat for \(role.rawValue)")
            seats.append(.seat(position: position(for: role), direction: direction(for: role)))
        }
        
        // 3. Ensure we have exactly 5 seats to silence the visionOS capacity warning
        while seats.count < 5 {
            print("[SpatialTemplate] Adding dummy spectator seat for capacity")
            let dummyPos: SpatialTemplateElementPosition = .app.offsetBy(x: 0, z: 2.0)
            seats.append(.seat(position: dummyPos, direction: .lookingAt(.app.offsetBy(x: 0, z: 1.0))))
        }
        
        print("[SpatialTemplate] Final built template has \(seats.count) seats.")
        return seats
    }
}
