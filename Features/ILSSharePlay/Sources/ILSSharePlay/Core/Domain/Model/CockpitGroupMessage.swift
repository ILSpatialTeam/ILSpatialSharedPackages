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
    case launchSimulation(AppLaunchMode, roles: [String: SessionRole])
    case exitSimulation
    case sopStepChanged(Int)
    case requestFullStateSnapshot
    case fullStateSnapshot(
        switches: [String: SwitchState],
        buttons: [String: Bool],
        knobs: [String: Int],
        throttle: Float,
        cockpitPrep: CockpitPrep,
        sopStepIndex: Int
    )
}

