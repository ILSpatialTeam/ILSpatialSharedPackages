import Foundation
import simd

public extension simd_float4x4 {
    /// Extracts the translation component from a 4x4 matrix
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    /// Extracts the rotation component from a 4x4 matrix as a quaternion
    var rotation: simd_quatf {
        return simd_quatf(self)
    }
}

public extension simd_float3 {
    /// Normalizes the 3D vector, returning zero if the length is 0
    var safeNormalized: simd_float3 {
        let len = simd_length(self)
        return len > 0 ? self / len : .zero
    }
}
