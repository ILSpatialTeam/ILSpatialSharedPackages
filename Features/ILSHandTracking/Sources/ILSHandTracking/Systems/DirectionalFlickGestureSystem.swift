import RealityKit
import ARKit
import ILSFoundation
import simd

/// A generic system that uses `HandTrackingService` to detect deliberate directional flicks (up, down, left, right).
/// It looks for entities with `FlickGestureComponent` and updates them when a flick is detected.
public struct DirectionalFlickGestureSystem: System {
    public static let query = EntityQuery(where: .has(FlickGestureComponent.self))
    private let logger = ILLogger(subsystem: .app, category: "FlickGesture")
    
    private var rightWasFacingDown: Bool = false
    private var rightWasFacingLeft: Bool = false
    private var rightWasFacingRight: Bool = false
    
    private var leftWasFacingDown: Bool = false
    private var leftWasFacingRight: Bool = false
    private var leftWasFacingLeft: Bool = false
    
    private var isFirstRightFrame: Bool = true
    private var isFirstLeftFrame: Bool = true
    
    private var cooldown: TimeInterval = 0
    public var globalCooldownDuration: TimeInterval = 0.3
    
    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        let deltaTime = context.deltaTime
        if cooldown > 0 {
            cooldown -= deltaTime
        }
        
        var rightFlick: FlickDirection? = nil
        var leftFlick: FlickDirection? = nil
        
        // --- RIGHT HAND ---
        if let rightHand = HandTrackingService.shared.latestRightHand {
            if let wrist = rightHand.handSkeleton?.joint(.wrist),
               let indexTip = rightHand.handSkeleton?.joint(.indexFingerTip),
               let middleTip = rightHand.handSkeleton?.joint(.middleFingerTip),
               wrist.isTracked, indexTip.isTracked, middleTip.isTracked {
                
                let handTransform = rightHand.originFromAnchorTransform
                let wristPos = simd_make_float3(matrix_multiply(handTransform, wrist.anchorFromJointTransform).columns.3)
                let indexPos = simd_make_float3(matrix_multiply(handTransform, indexTip.anchorFromJointTransform).columns.3)
                let middlePos = simd_make_float3(matrix_multiply(handTransform, middleTip.anchorFromJointTransform).columns.3)
                
                let distIndex = simd_distance(wristPos, indexPos)
                let distMiddle = simd_distance(wristPos, middlePos)
                let areFingersExtended = distIndex > 0.08 && distMiddle > 0.08
                
                let handDir = normalize(middlePos - wristPos)
                
                let isFacingDown = handDir.y < -0.45
                let isFacingLeft = handDir.x < -0.45
                let isFacingRight = handDir.x > 0.45
                
                if isFirstRightFrame {
                    rightWasFacingDown = isFacingDown
                    rightWasFacingLeft = isFacingLeft
                    rightWasFacingRight = isFacingRight
                    isFirstRightFrame = false
                } else {
                    if areFingersExtended && cooldown <= 0 {
                        if isFacingDown && !rightWasFacingDown {
                            rightFlick = .down
                        } else if isFacingLeft && !rightWasFacingLeft {
                            rightFlick = .left
                        } else if isFacingRight && !rightWasFacingRight {
                            rightFlick = .right
                        }
                    }
                    rightWasFacingDown = isFacingDown
                    rightWasFacingLeft = isFacingLeft
                    rightWasFacingRight = isFacingRight
                }
            }
        } else {
            isFirstRightFrame = true
        }
        
        // --- LEFT HAND ---
        if let leftHand = HandTrackingService.shared.latestLeftHand {
            if let wrist = leftHand.handSkeleton?.joint(.wrist),
               let indexTip = leftHand.handSkeleton?.joint(.indexFingerTip),
               let middleTip = leftHand.handSkeleton?.joint(.middleFingerTip),
               wrist.isTracked, indexTip.isTracked, middleTip.isTracked {
                
                let handTransform = leftHand.originFromAnchorTransform
                let wristPos = simd_make_float3(matrix_multiply(handTransform, wrist.anchorFromJointTransform).columns.3)
                let indexPos = simd_make_float3(matrix_multiply(handTransform, indexTip.anchorFromJointTransform).columns.3)
                let middlePos = simd_make_float3(matrix_multiply(handTransform, middleTip.anchorFromJointTransform).columns.3)
                
                let distIndex = simd_distance(wristPos, indexPos)
                let distMiddle = simd_distance(wristPos, middlePos)
                let areFingersExtended = distIndex > 0.08 && distMiddle > 0.08
                
                let handDir = normalize(middlePos - wristPos)
                
                let isFacingDown = handDir.y < -0.45
                let isFacingRight = handDir.x > 0.45
                let isFacingLeft = handDir.x < -0.45
                
                if isFirstLeftFrame {
                    leftWasFacingDown = isFacingDown
                    leftWasFacingRight = isFacingRight
                    leftWasFacingLeft = isFacingLeft
                    isFirstLeftFrame = false
                } else {
                    if areFingersExtended && cooldown <= 0 {
                        if isFacingDown && !leftWasFacingDown {
                            leftFlick = .down
                        } else if isFacingRight && !leftWasFacingRight {
                            leftFlick = .right
                        } else if isFacingLeft && !leftWasFacingLeft {
                            leftFlick = .left
                        }
                    }
                    leftWasFacingDown = isFacingDown
                    leftWasFacingRight = isFacingRight
                    leftWasFacingLeft = isFacingLeft
                }
            }
        } else {
            isFirstLeftFrame = true
        }
        
        // Only update components if a flick occurred
        if rightFlick != nil || leftFlick != nil {
            cooldown = globalCooldownDuration
            
            for entity in context.scene.performQuery(Self.query) {
                var component = entity.components[FlickGestureComponent.self]!
                component.lastRightFlick = rightFlick
                component.lastLeftFlick = leftFlick
                component.lastFlickTime = Date().timeIntervalSince1970
                entity.components.set(component)
                
                logger.info("Flick detected! Right: \(rightFlick?.rawValue ?? "none"), Left: \(leftFlick?.rawValue ?? "none")")
            }
        }
    }
}
