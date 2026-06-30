import Foundation
import RealityKit
import simd

public struct TubeMeshBuilder {
    /// Generates a MeshDescriptor for a continuous tube passing through the given points.
    public static func generateMeshDescriptor(from points: [SIMD3<Float>], radius: Float) -> MeshDescriptor {
        var descriptor = MeshDescriptor(name: "tube")
        if points.count < 2 { return descriptor }

        let radialSegments = 6
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Generate parallel transport frames
        var tangents: [SIMD3<Float>] = []
        for i in 0..<points.count {
            let t: SIMD3<Float>
            if i == 0 {
                t = normalize(points[1] - points[0])
            } else if i == points.count - 1 {
                t = normalize(points[i] - points[i-1])
            } else {
                t = normalize(points[i+1] - points[i-1])
            }
            tangents.append(t == .zero ? [0, 1, 0] : t)
        }

        var up = SIMD3<Float>(0, 1, 0)
        if abs(dot(tangents[0], up)) > 0.99 {
            up = SIMD3<Float>(1, 0, 0)
        }
        var currentNormal = normalize(cross(tangents[0], up))

        for i in 0..<points.count {
            let p = points[i]
            let t = tangents[i]
            
            // Parallel transport the normal
            currentNormal = normalize(currentNormal - dot(currentNormal, t) * t)
            let b = normalize(cross(t, currentNormal))

            for j in 0..<radialSegments {
                let angle = Float(j) * 2.0 * .pi / Float(radialSegments)
                let cosA = cos(angle)
                let sinA = sin(angle)
                
                let normal = cosA * currentNormal + sinA * b
                positions.append(p + normal * radius)
                normals.append(normal)
            }
        }

        for i in 0..<(points.count - 1) {
            for j in 0..<radialSegments {
                let current = UInt32(i * radialSegments + j)
                let next = UInt32(i * radialSegments + (j + 1) % radialSegments)
                let currentForward = UInt32((i + 1) * radialSegments + j)
                let nextForward = UInt32((i + 1) * radialSegments + (j + 1) % radialSegments)

                // Triangle 1
                indices.append(contentsOf: [current, next, currentForward])
                // Triangle 2
                indices.append(contentsOf: [next, nextForward, currentForward])
            }
        }

        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        
        return descriptor
    }
}
