import RealityKit
import simd

public struct ILHandTrackingComponent: Component {
    public var leftHandPosition: simd_float3?
    public var rightHandPosition: simd_float3?
    public var isPinchingLeft: Bool = false
    public var isPinchingRight: Bool = false
    
    public init() {}
}
