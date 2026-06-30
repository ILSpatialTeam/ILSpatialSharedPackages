import RealityKit
import Foundation

/// Stores appearance and continuous state for drawing
public struct DrawingComponent: Component {
    public var lastPlacedPosition: SIMD3<Float>? = nil
    
    // Appearance
    public var currentColor: SIMD4<Float> = [1, 1, 1, 1]
    public var sphereRadius: Float = 0.005
    
    // Active Stroke Tracking for Programmatic Meshes
    public var currentStrokeID: UUID? = nil
    public var activeStrokeEntity: Entity? = nil
    public var activeStrokePoints: [SIMD3<Float>] = []
    
    // Performance & Sync Tracking
    public var lastSharePlaySyncTime: TimeInterval = 0
    public var isGeneratingMesh: Bool = false
    
    public init() {}
}
