import RealityKit
import Foundation

/// System to handle the squash-and-glow hit animation for any entity with ILSquashAnimationComponent.
public struct ILSquashAnimationSystem: System {
    
    private let squashDuration: TimeInterval = 0.05
    private let restoreDuration: TimeInterval = 0.15
    private let totalDuration: TimeInterval = 0.20
    private let squashScale: Float = 0.92

    public init(scene: RealityKit.Scene) { }

    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        let currentTime = Date().timeIntervalSince1970
        
        for entity in entities {
            guard var animComponent = entity.components[ILSquashAnimationComponent.self] else { continue }
            
            // Check for animation intent
            if entity.components.has(ILSquashIntentComponent.self) {
                animComponent.isAnimating = true
                animComponent.animationStartTime = currentTime
                entity.components.remove(ILSquashIntentComponent.self)
                entity.components[ILSquashAnimationComponent.self] = animComponent
            }
            
            if !animComponent.isAnimating {
                continue
            }
            
            let elapsed = currentTime - animComponent.animationStartTime
            
            if elapsed < squashDuration {
                // Squashing down
                let progress = Float(elapsed / squashDuration)
                let currentScale = mix(animComponent.originalScale, animComponent.originalScale * squashScale, t: progress)
                entity.transform.scale = currentScale
            } else if elapsed < totalDuration {
                // Restoring
                let progress = Float((elapsed - squashDuration) / restoreDuration)
                let currentScale = mix(animComponent.originalScale * squashScale, animComponent.originalScale, t: progress)
                entity.transform.scale = currentScale
            } else {
                // Done
                entity.transform.scale = animComponent.originalScale
                animComponent.isAnimating = false
                entity.components[ILSquashAnimationComponent.self] = animComponent
            }
        }
    }
    
    // We query entities that either have an active animation or an intent to animate
    public static let query = EntityQuery(where: .has(ILSquashAnimationComponent.self))
}

// Helper for interpolation
fileprivate func mix(_ start: SIMD3<Float>, _ end: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    let clampedT = max(0, min(1, t))
    return start + (end - start) * clampedT
}
