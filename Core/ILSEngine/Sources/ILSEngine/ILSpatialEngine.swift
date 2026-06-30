import RealityKit

/// A centralized coordinator for setting up foundational ILSEngine systems.
/// Call `ILSpatialEngine.registerAllSystems()` at app launch.
public struct ILSpatialEngine {
    /// Registers all foundational RealityKit systems from ILSEngine.
    public static func registerAllSystems() {
        ILHittableComponent.registerComponent()
        ILHitEventComponent.registerComponent()
        ILSquashAnimationComponent.registerComponent()
        ILSquashIntentComponent.registerComponent()
        
        ILSquashAnimationSystem.registerSystem()
    }
}
