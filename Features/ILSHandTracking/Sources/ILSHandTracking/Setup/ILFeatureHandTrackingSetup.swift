import RealityKit
import ILSFoundation

public struct ILFeatureHandTrackingSetup {
    public static func registerSystems() {
        ILHandTrackingComponent.registerComponent()
        ILHandAnchorComponent.registerComponent()
        
        ILHandTrackingUpdateSystem.registerSystem()
    }
}
