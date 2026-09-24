import GroupActivities
import CockpitDomain

extension SessionRole: SpatialTemplateRole {}

/// Seats and content use the same shared immersive-space coordinates.
struct CockpitSpatialTemplate: SpatialTemplate {
    let positions: [CockpitRole: SIMD3<Float>]

    var elements: [any SpatialTemplateElement] {
        SessionRole.allCases.compactMap { role -> SpatialTemplateSeatElement? in
            guard let position = positions[role.cockpitRole] else { return nil }
            return .seat(
                position: .app.offsetBy(x: Double(position.x), z: Double(position.z)),
                direction: .lookingAt(.app.offsetBy(x: Double(position.x), z: Double(position.z) - 10)),
                role: role
            )
        }
    }
}
