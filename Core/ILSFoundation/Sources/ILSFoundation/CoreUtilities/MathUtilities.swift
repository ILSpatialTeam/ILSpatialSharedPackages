import Foundation
import simd

public enum MathUtilities {
    
    /// Converts degrees to radians
    public static func degreesToRadians(_ degrees: Float) -> Float {
        return degrees * .pi / 180.0
    }
    
    /// Converts radians to degrees
    public static func radiansToDegrees(_ radians: Float) -> Float {
        return radians * 180.0 / .pi
    }
    
    /// Computes the distance between two 3D points
    public static func distance(from: simd_float3, to: simd_float3) -> Float {
        return simd_distance(from, to)
    }
}
