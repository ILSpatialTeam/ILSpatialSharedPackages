import GroupActivities
import CockpitDomain

extension SessionRole: SpatialTemplateRole {}

/// Seats and content use the same shared immersive-space coordinates.
struct CockpitSpatialTemplate: SpatialTemplate {
    let positions: [CockpitRole: SIMD3<Float>]

    /// Simulator mock Personas cannot claim roles. Reserve only the local
    /// seat in preview mode and let mocks fill the other authored positions.
    /// nil retains role reservations for every seat in a real session.
    var previewRole: SessionRole? = nil

    var elements: [any SpatialTemplateElement] {
        SessionRole.allCases.compactMap { role -> SpatialTemplateSeatElement? in
            guard let position = positions[role.cockpitRole] else { return nil }
            return .seat(
                position: .app.offsetBy(x: Double(position.x), z: Double(position.z)),
                direction: .lookingAt(.app.offsetBy(x: Double(position.x), z: Double(position.z) - 10)),
                role: previewRole == nil || previewRole == role ? role : nil
            )
        }
    }
}
