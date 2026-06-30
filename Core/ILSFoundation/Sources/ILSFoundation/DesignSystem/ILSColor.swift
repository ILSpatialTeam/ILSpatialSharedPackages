import Foundation

/// A platform-agnostic, data-driven color representation.
/// Used in domain logic and ECS systems without coupling to SwiftUI or UIKit.
public struct ILSColor: Codable, Equatable {
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float
    
    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    public static let white  = ILSColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    public static let black  = ILSColor(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    public static let red    = ILSColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
    public static let green  = ILSColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
    public static let blue   = ILSColor(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
    public static let cyan   = ILSColor(r: 0.0, g: 1.0, b: 1.0, a: 1.0)
    public static let yellow = ILSColor(r: 1.0, g: 1.0, b: 0.0, a: 1.0)
    public static let purple = ILSColor(r: 0.5, g: 0.0, b: 0.5, a: 1.0)
    public static let clear  = ILSColor(r: 0.0, g: 0.0, b: 0.0, a: 0.0)

    public var simd: SIMD4<Float> {
        return SIMD4<Float>(r, g, b, a)
    }
}
