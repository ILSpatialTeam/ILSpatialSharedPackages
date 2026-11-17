
//
//  ILSpatialHandPoseProvider.swift
//  CockpitDomain
//
//  Created by Tafani Rabbani on 03/08/26.
//

import ARKit
import simd

/// Adapter: the only place in the codebase that touches ILSpatial and
/// ARKit hand-skeleton APIs. Translates HandAnchor → domain HandPose.
@MainActor
public final class ILSpatialHandPoseProvider: HandPoseProviding {
    public init() {}

    public var leftHand: HandPose? {
        makePose(from: HandTrackingService.shared.latestLeftHand, chirality: .left)
    }

    public var rightHand: HandPose? {
        makePose(from: HandTrackingService.shared.latestRightHand, chirality: .right)
    }

    public func start() async throws {
        try await HandTrackingService.shared.start()
    }

    public func stop() {
        HandTrackingService.shared.stop()
    }

    private func makePose(from anchor: HandAnchor?, chirality: HandPose.Chirality) -> HandPose? {
        guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else {
            return nil
        }

        // Anchor-space position: used for curl detection (distances within the hand).
        func anchorPosition(_ name: HandSkeleton.JointName) -> SIMD3<Float> {
            let column = skeleton.joint(name).anchorFromJointTransform.columns.3
            return SIMD3<Float>(column.x, column.y, column.z)
        }

        // World-space position: used for interaction with scene entities.
        func worldPosition(_ name: HandSkeleton.JointName) -> SIMD3<Float> {
            let column = (anchor.originFromAnchorTransform
                          * skeleton.joint(name).anchorFromJointTransform).columns.3
            return SIMD3<Float>(column.x, column.y, column.z)
        }

        let wrist = anchorPosition(.wrist)
        let fingers: [(tip: HandSkeleton.JointName, knuckle: HandSkeleton.JointName)] = [
            (.indexFingerTip, .indexFingerKnuckle),
            (.middleFingerTip, .middleFingerKnuckle),
            (.ringFingerTip, .ringFingerKnuckle),
            (.littleFingerTip, .littleFingerKnuckle)
        ]

        let curledCount = fingers.reduce(into: 0) { count, joints in
            let curled = HandPoseAnalysis.isFingerCurled(
                tipToWristDistance: simd_distance(anchorPosition(joints.tip), wrist),
                knuckleToWristDistance: simd_distance(anchorPosition(joints.knuckle), wrist)
            )
            if curled { count += 1 }
        }

        let rayJoints: [(HandSkeleton.JointName, HandSkeleton.JointName, HandSkeleton.JointName)] = [
            (.thumbTip, .thumbIntermediateTip, .thumbKnuckle),
            (.indexFingerTip, .indexFingerIntermediateTip, .indexFingerKnuckle),
            (.middleFingerTip, .middleFingerIntermediateTip, .middleFingerKnuckle),
            (.ringFingerTip, .ringFingerIntermediateTip, .ringFingerKnuckle),
            (.littleFingerTip, .littleFingerIntermediateTip, .littleFingerKnuckle)
        ]
        let fingerRays = rayJoints.map { tip, distal, knuckle in
            let delta = worldPosition(tip) - worldPosition(distal)
            let length = simd_length(delta)
            return HandPose.Finger(
                tip: worldPosition(tip),
                direction: length > 0.0001 ? delta / length : .zero,
                isCurled: HandPoseAnalysis.isFingerCurled(
                    tipToWristDistance: simd_distance(anchorPosition(tip), wrist),
                    knuckleToWristDistance: simd_distance(anchorPosition(knuckle), wrist)),
                isTracked: skeleton.joint(tip).isTracked && skeleton.joint(distal).isTracked && length > 0.0001
            )
        }

        let jointDataList = skeleton.allJoints.map { joint in
            HandPose.JointData(
                name: joint.name.description,
                parentFromJointRotation: simd_quatf(joint.parentFromJointTransform)
            )
        }

        return HandPose(
            chirality: chirality,
            originTransform: anchor.originFromAnchorTransform,
            palmPosition: worldPosition(.middleFingerKnuckle),
            thumbTipPosition: worldPosition(.thumbTip),
            indexTipPosition: worldPosition(.indexFingerTip),
            middleTipPosition: worldPosition(.middleFingerTip),
            ringTipPosition: worldPosition(.ringFingerTip),
            littleTipPosition: worldPosition(.littleFingerTip),
            isFistClosed: HandPoseAnalysis.isFistClosed(curledFingerCount: curledCount),
            joints: jointDataList,
            fingers: fingerRays
        )
    }
}

public enum HandPoseAnalysis {
    /// A finger counts as curled when its tip is closer to the wrist than its
    /// knuckle is. ARKit loses per-joint tracking when fingers curl into a
    /// fist, but the estimated transforms remain accurate enough for this
    /// distance comparison — which is why callers deliberately ignore the
    /// per-joint `isTracked` flag.
    public static func isFingerCurled(
        tipToWristDistance: Float,
        knuckleToWristDistance: Float
    ) -> Bool {
        tipToWristDistance < knuckleToWristDistance
    }

    /// The grab pose requires at least 3 of the 4 non-thumb fingers curled.
    public static func isFistClosed(curledFingerCount: Int, requiredCount: Int = 3) -> Bool {
        curledFingerCount >= requiredCount
    }
}
