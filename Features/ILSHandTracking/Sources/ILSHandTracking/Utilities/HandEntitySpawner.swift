import RealityKit
import ILSEngine

/// A generic spawner for setting up Hand Tracking Entities in ILSpatial
public struct HandEntitySpawner {
    
    /// Spawns the default left and right hand tracking entities, configured with `ILHandTrackingComponent`.
    /// - Returns: An array of entities representing the hands.
    public static func spawnHands() -> [Entity] {
        let rightHand = Entity()
        rightHand.name = "RightHandAnchor"
        rightHand.components.set(ILHandTrackingComponent())
        
        let leftHand = Entity()
        leftHand.name = "LeftHandAnchor"
        leftHand.components.set(ILHandTrackingComponent())
        
        return [rightHand, leftHand]
    }
}
