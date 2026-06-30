import ARKit
import RealityKit
import simd

/// A collection of generic utilities for calculating complex hand poses and gesture states
/// from ARKit Hand Skeletons.
public struct ILHandPoseUtilities {
    
    /// Checks if a specific finger is curled by comparing the distance from its tip to the wrist
    /// versus the distance from its knuckle to the wrist.
    public static func isFingerCurled(skeleton: HandSkeleton, tip: HandSkeleton.JointName, knuckle: HandSkeleton.JointName) -> Bool {
        let tipJoint = skeleton.joint(tip)
        let knuckleJoint = skeleton.joint(knuckle)
        let wristJoint = skeleton.joint(.wrist)
        
        guard tipJoint.isTracked, knuckleJoint.isTracked, wristJoint.isTracked else {
            return false
        }
        
        let tipDistance = simd_distance(tipJoint.anchorFromJointTransform.columns.3.xyz, wristJoint.anchorFromJointTransform.columns.3.xyz)
        let knuckleDistance = simd_distance(knuckleJoint.anchorFromJointTransform.columns.3.xyz, wristJoint.anchorFromJointTransform.columns.3.xyz)
        
        // If the tip is closer to the wrist than the knuckle, the finger is curled
        return tipDistance < knuckleDistance
    }
    
    /// Specific helper for the thumb, comparing tip to intermediate base joint.
    public static func isThumbCurled(skeleton: HandSkeleton) -> Bool {
        let tipJoint = skeleton.joint(.thumbTip)
        let baseJoint = skeleton.joint(.thumbIntermediateBase)
        let wristJoint = skeleton.joint(.wrist)
        
        guard tipJoint.isTracked, baseJoint.isTracked, wristJoint.isTracked else {
            return false
        }
        
        let tipDistance = simd_distance(tipJoint.anchorFromJointTransform.columns.3.xyz, wristJoint.anchorFromJointTransform.columns.3.xyz)
        let baseDistance = simd_distance(baseJoint.anchorFromJointTransform.columns.3.xyz, wristJoint.anchorFromJointTransform.columns.3.xyz)
        
        return tipDistance < baseDistance
    }
    
    /// Calculates the world position of a specific joint.
    public static func worldPosition(of jointName: HandSkeleton.JointName, handAnchor: HandAnchor, skeleton: HandSkeleton) -> SIMD3<Float> {
        let joint = skeleton.joint(jointName)
        let jointTransform = matrix_multiply(handAnchor.originFromAnchorTransform, joint.anchorFromJointTransform)
        return jointTransform.columns.3.xyz
    }
}

// MARK: - SIMD Extensions for utilities
extension simd_float4 {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
