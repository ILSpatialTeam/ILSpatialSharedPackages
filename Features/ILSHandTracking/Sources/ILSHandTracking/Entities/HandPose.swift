//
//  HandPose.swift
//  ILSHandTracking
//
//  Created by Fatakhillah Khaqo on 17/11/26.
//

import simd

/// A framework-neutral snapshot of one tracked hand.
/// This is the ONLY hand representation the rest of the app sees —
/// ARKit's HandAnchor/HandSkeleton never leave CoreSpatial.
public struct HandPose: Equatable, Sendable {
    public enum Chirality: Sendable {
        case left
        case right
    }

    public struct JointData: Equatable, Sendable {
        public let name: String
        public let parentFromJointRotation: simd_quatf

        public init(name: String, parentFromJointRotation: simd_quatf) {
            self.name = name
            self.parentFromJointRotation = parentFromJointRotation
        }
    }

    public struct Finger: Equatable, Sendable {
        public let tip: SIMD3<Float>
        public let direction: SIMD3<Float>
        public let isCurled: Bool
        public let isTracked: Bool

        public init(tip: SIMD3<Float>, direction: SIMD3<Float>, isCurled: Bool, isTracked: Bool) {
            self.tip = tip
            self.direction = direction
            self.isCurled = isCurled
            self.isTracked = isTracked
        }
    }

    /// Thumb, index, middle, ring, little; empty for providers without finger rays.
    public let fingers: [Finger]

    public let chirality: Chirality

    /// Full 6-DoF wrist anchor transform in world space
    public let originTransform: simd_float4x4

    /// World-space palm position (middle-finger knuckle joint).
    public let palmPosition: SIMD3<Float>
    /// World-space thumb tip position.
    public let thumbTipPosition: SIMD3<Float>
    /// World-space index fingertip position.
    public let indexTipPosition: SIMD3<Float>

    /// True when 3 or more fingers are curled toward the wrist (grab pose).
    public let middleTipPosition: SIMD3<Float>
    public let ringTipPosition: SIMD3<Float>
    public let littleTipPosition: SIMD3<Float>
    public let isFistClosed: Bool

    /// Skeletal joints relative rotations
    public let joints: [JointData]

    /// True wrist root position in world space
    public var rootPosition: SIMD3<Float> {
        SIMD3<Float>(originTransform.columns.3.x, originTransform.columns.3.y, originTransform.columns.3.z)
    }

    /// True wrist root orientation in world space
    public var rootOrientation: simd_quatf {
        simd_quatf(originTransform)
    }

    // Kecuali Jempol
    public var nonThumbFingertips: [SIMD3<Float>] {
        [indexTipPosition, middleTipPosition, ringTipPosition, littleTipPosition]
    }

    public init(
        chirality: Chirality,
        originTransform: simd_float4x4 = matrix_identity_float4x4,
        palmPosition: SIMD3<Float>,
        thumbTipPosition: SIMD3<Float>,
        indexTipPosition: SIMD3<Float>,
        middleTipPosition: SIMD3<Float>,
        ringTipPosition: SIMD3<Float>,
        littleTipPosition: SIMD3<Float>,
        isFistClosed: Bool,
        joints: [JointData] = [],
        fingers: [Finger] = []
    ) {
        self.chirality = chirality
        self.originTransform = originTransform
        self.palmPosition = palmPosition
        self.thumbTipPosition = thumbTipPosition
        self.indexTipPosition = indexTipPosition
        self.middleTipPosition = middleTipPosition
        self.ringTipPosition = ringTipPosition
        self.littleTipPosition = littleTipPosition
        self.isFistClosed = isFistClosed
        self.joints = joints
        self.fingers = fingers
    }
}
