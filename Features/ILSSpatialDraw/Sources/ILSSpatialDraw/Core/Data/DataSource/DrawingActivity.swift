import Foundation
import GroupActivities

/// Defines the SharePlay activity for collaborative drawing
public struct DrawingActivity: GroupActivity {
    public static let activityIdentifier = "com.ratafani.SpatialDraw.DrawingActivity"
    
    public init() {}
    
    public var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "SpatialDraw"
        meta.subtitle = "Draw together in 3D space"
        meta.type = .generic
        meta.supportsContinuationOnTV = false
        return meta
    }
}
