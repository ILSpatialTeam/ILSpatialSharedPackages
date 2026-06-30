import simd

/// Platform-agnostic RGBA color.
/// No UIKit, no SwiftUI, no RealityKit dependency — safe to use at any layer.
public struct ILSColor: Codable, Equatable, Hashable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float

    public init(r: Float, g: Float, b: Float, a: Float = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Convert to SIMD4 for use in RealityKit/Metal pipelines
    public var simd: SIMD4<Float> { [r, g, b, a] }

    // MARK: - Presets
    public static let white  = ILSColor(r: 1.0, g: 1.0, b: 1.0)
    public static let red    = ILSColor(r: 1.0, g: 0.2, b: 0.15)
    public static let cyan   = ILSColor(r: 0.0, g: 0.9, b: 1.0)
    public static let yellow = ILSColor(r: 1.0, g: 0.9, b: 0.1)
    public static let green  = ILSColor(r: 0.2, g: 1.0, b: 0.4)
    public static let purple = ILSColor(r: 0.7, g: 0.3, b: 1.0)
}
