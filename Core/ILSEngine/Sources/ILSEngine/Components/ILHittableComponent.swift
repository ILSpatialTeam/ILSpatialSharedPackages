import RealityKit

/// Marks an entity as capable of being hit by a spatial interaction (e.g., hand collision).
public struct ILHittableComponent: Component {
    public var hitRadius: Float
    
    public init(hitRadius: Float = 0.1) {
        self.hitRadius = hitRadius
    }
}
