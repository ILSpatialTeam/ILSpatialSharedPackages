import ARKit
import RealityKit

/// An ECS component that stores the latest ARKit HandAnchors for an entity.
///
/// Populated each frame by `ILHandTrackingUpdateSystem`. Attach this to any entity
/// that needs direct access to raw `HandAnchor` data — for example, a DrawController
/// entity in a drawing feature — without coupling to `HandTrackingSystem`'s global state.
///
/// Usage in a RealityView:
/// ```swift
/// drawController.components.set(ILHandAnchorComponent())
/// ```
/// `DrawingSystem` (or any other system) then reads:
/// ```swift
/// let anchor = entity.components[ILHandAnchorComponent.self]?.rightHand
/// ```
public struct ILHandAnchorComponent: Component {
    public var rightHand: HandAnchor?
    public var leftHand: HandAnchor?

    public init() {}
}
