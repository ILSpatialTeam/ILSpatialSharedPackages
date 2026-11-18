import RealityKit
import ARKit
import ILSEngine
import ILSFoundation

/// A system that synchronizes ARKit HandTracking data into two ECS components:
///
/// - `ILHandTrackingComponent` — stores processed position + pinch state (coarse, high-level)
/// - `ILHandAnchorComponent`   — stores the raw `HandAnchor` for systems that need full
///   skeleton access (e.g., DrawingSystem for finger-curl detection). Prefer this over
///   accessing `HandTrackingSystem.latestRightHand` directly from other packages.
public struct ILHandTrackingUpdateSystem: System {
    private static let trackingQuery = EntityQuery(where: .has(ILHandTrackingComponent.self))
    private static let anchorQuery   = EntityQuery(where: .has(ILHandAnchorComponent.self))

    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        let service = HandTrackingService.shared
        
        let leftAnchor  = service.latestLeftHand
        let rightAnchor = service.latestRightHand

        // 1. Update high-level ILHandTrackingComponent (position / pinch)
        for entity in context.scene.performQuery(Self.trackingQuery) {
            guard var component = entity.components[ILHandTrackingComponent.self] else { continue }

            if entity.name == "LeftHandAnchor", let leftAnchor = leftAnchor {
                component.leftHandPosition = leftAnchor.originFromAnchorTransform.translation
            } else if entity.name == "RightHandAnchor", let rightAnchor = rightAnchor {
                component.rightHandPosition = rightAnchor.originFromAnchorTransform.translation
            }

            entity.components.set(component)
        }

        // 2. Update raw ILHandAnchorComponent — used by systems that need full skeleton access.
        //    This is the ECS-friendly alternative to calling HandTrackingSystem.latestRightHand
        //    from unrelated packages.
        for entity in context.scene.performQuery(Self.anchorQuery) {
            if var comp = entity.components[ILHandAnchorComponent.self] {
                comp.rightHand = rightAnchor
                comp.leftHand  = leftAnchor
                entity.components.set(comp)
            }
        }
    }
}

extension simd_float4x4 {
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
}
