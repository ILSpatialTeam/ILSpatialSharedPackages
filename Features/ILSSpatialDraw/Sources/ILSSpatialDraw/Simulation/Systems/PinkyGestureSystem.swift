import Foundation
import RealityKit
import ARKit
import ILSHandTracking
import ILSSpatialDraw
import ILSSpatialAudio

public struct PinkyGestureSystem: System {
    static let query = EntityQuery(where: .has(IsDrawingComponent.self) && .has(ILHandAnchorComponent.self) && .has(DrawingComponent.self))
    
    public init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        for entity in entities {
            guard var isDrawingComp = entity.components[IsDrawingComponent.self],
                  let anchorComp = entity.components[ILHandAnchorComponent.self],
                  let anchor = anchorComp.rightHand,
                  let skeleton = anchor.handSkeleton else {
                
                if var idc = entity.components[IsDrawingComponent.self] {
                    idc.frameCount = 0
                    idc.isActive = false
                    entity.components.set(idc)
                }
                continue
            }
            
            // We use the standard index-thumb pinch for maximum reliability on both Simulator and Physical Device.
            // The previous 'Pinky Gesture' was too geometrically strict for ARKit to consistently recognize.
            let indexTip = ILHandPoseUtilities.worldPosition(of: .indexFingerTip, handAnchor: anchor, skeleton: skeleton)
            let thumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: anchor, skeleton: skeleton)
            
            let dist = simd_distance(indexTip, thumbTip)
            // If the distance between index tip and thumb tip is less than 2cm, we consider it a pinch!
            let pinkyGestureActive = dist < 0.02
            let activeJoint: ARKit.HandSkeleton.JointName = .indexFingerTip
            
            // Throttle logging to avoid spam
            if Int.random(in: 1...30) == 1 {
                print("[PinkyGestureSystem] index-thumb distance: \(dist) meters. active: \(pinkyGestureActive)")
            }
            
            // Anti-jitter: require 3 consecutive frames
            if pinkyGestureActive {
                isDrawingComp.frameCount = min(isDrawingComp.frameCount + 1, 10)
            } else {
                isDrawingComp.frameCount = max(isDrawingComp.frameCount - 1, 0)
            }
            
            isDrawingComp.isActive = (isDrawingComp.frameCount >= 3)
            
            if isDrawingComp.isActive {
                isDrawingComp.tipPosition = ILHandPoseUtilities.worldPosition(
                    of: activeJoint, handAnchor: anchor, skeleton: skeleton
                )
            }
            
            entity.components.set(isDrawingComp)
        }
    }
}
