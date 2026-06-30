import RealityKit
import Foundation

/// Stores the necessary state to perform a physical squash-and-glow animation.
public struct ILSquashAnimationComponent: Component {
    public var originalScale: SIMD3<Float>
    public var isAnimating: Bool = false
    public var animationStartTime: TimeInterval = 0
    
    public init(originalScale: SIMD3<Float> = .one) {
        self.originalScale = originalScale
    }
}
