import RealityKit

/// A transient component attached to an entity for a single frame when a collision is detected.
/// App-level systems should query for this, perform business logic (like playing sound), and then remove it.
public struct ILHitEventComponent: Component {
    public var hitPosition: SIMD3<Float>
    
    public init(hitPosition: SIMD3<Float> = .zero) {
        self.hitPosition = hitPosition
    }
}
