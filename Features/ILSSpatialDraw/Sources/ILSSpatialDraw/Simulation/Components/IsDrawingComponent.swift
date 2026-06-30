import RealityKit
import Foundation

/// Set by the gesture system to indicate that the user is actively drawing.
public struct IsDrawingComponent: Component {
    public var isActive: Bool
    public var tipPosition: SIMD3<Float>
    public var frameCount: Int
    
    public init(isActive: Bool = false, tipPosition: SIMD3<Float> = .zero, frameCount: Int = 0) {
        self.isActive = isActive
        self.tipPosition = tipPosition
        self.frameCount = frameCount
    }
}
