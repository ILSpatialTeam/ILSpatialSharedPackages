import Foundation

/// Data packet sent between devices via SharePlay
public struct StrokeMessage: Codable, Sendable {
    public let id: UUID
    public let strokeID: UUID
    public let senderID: UUID
    public let action: StrokeAction
    
    // Drawing data (only used when action == .addPoint)
    public let positionX: Float
    public let positionY: Float
    public let positionZ: Float
    public let colorR: Float
    public let colorG: Float
    public let colorB: Float
    public let colorA: Float
    public let radius: Float
    
    public enum StrokeAction: String, Codable, Sendable {
        case addPoint
        case endStroke
        case clear
    }
    
    /// Convenience: create an add point message
    public static func addPoint(
        strokeID: UUID,
        senderID: UUID,
        position: SIMD3<Float>,
        color: SIMD4<Float>,
        radius: Float
    ) -> StrokeMessage {
        StrokeMessage(
            id: UUID(),
            strokeID: strokeID,
            senderID: senderID,
            action: .addPoint,
            positionX: position.x,
            positionY: position.y,
            positionZ: position.z,
            colorR: color.x,
            colorG: color.y,
            colorB: color.z,
            colorA: color.w,
            radius: radius
        )
    }
    
    /// Convenience: create an end stroke message
    public static func endStroke(strokeID: UUID, senderID: UUID) -> StrokeMessage {
        StrokeMessage(
            id: UUID(),
            strokeID: strokeID,
            senderID: senderID,
            action: .endStroke,
            positionX: 0, positionY: 0, positionZ: 0,
            colorR: 0, colorG: 0, colorB: 0, colorA: 0,
            radius: 0
        )
    }
    
    /// Convenience: create a clear message
    public static func clear(senderID: UUID) -> StrokeMessage {
        StrokeMessage(
            id: UUID(),
            strokeID: UUID(), // unused
            senderID: senderID,
            action: .clear,
            positionX: 0, positionY: 0, positionZ: 0,
            colorR: 0, colorG: 0, colorB: 0, colorA: 0,
            radius: 0
        )
    }
    
    /// Reconstruct SIMD types
    public var position: SIMD3<Float> { [positionX, positionY, positionZ] }
    public var color: SIMD4<Float> { [colorR, colorG, colorB, colorA] }
}
