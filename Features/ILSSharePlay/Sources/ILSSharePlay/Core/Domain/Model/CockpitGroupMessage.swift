import Foundation
import CockpitDomain

public enum CockpitGroupMessage: Codable, Sendable {
    case switchChanged(entityName: String, state: SwitchState)
    case buttonChanged(entityName: String, isOn: Bool)
    case knobChanged(entityName: String, index: Int)
    case throttleChanged(Float)
    case cockpitPrepChanged(CockpitPrep)
    case roleAssigned(participantID: String, role: SessionRole)
    case syncJoinOrder([String])
    case heartbeat
    case fullStateSnapshot(
        switches: [String: SwitchState],
        buttons: [String: Bool],
        knobs: [String: Int],
        throttle: Float,
        cockpitPrep: CockpitPrep
    )
    /// Option B — pilot broadcasts its ARKit-derived world-anchor offset so
    /// every participant shifts their cockpit scene to the same world position.
    case worldOriginOffset(x: Float, y: Float, z: Float)
}

