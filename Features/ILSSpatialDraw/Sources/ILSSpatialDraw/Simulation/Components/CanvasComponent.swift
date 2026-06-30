import RealityKit

/// Marks the canvas root entity — all drawn spheres are children of this.
///
/// `clearRequested`: set to `true` from any view or system to trigger a canvas wipe.
/// `DrawingSystem` consumes the flag each frame and resets it to `false`.
public struct CanvasComponent: Component, Codable {
    public var strokeCount: Int = 0

    /// Write `true` to request a canvas clear. `DrawingSystem` will process it
    /// next frame and reset the flag automatically.
    public var clearRequested: Bool = false

    public init() {}
}
