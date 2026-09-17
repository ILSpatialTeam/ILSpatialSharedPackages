import Foundation
import GroupActivities

public struct CockpitGroupActivity: GroupActivity {
    public static let activityIdentifier = "id.infinitelearning.airbus.cockpit-session"

    public init() {}

    public var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Adaptive Learning Intelligence"
        meta.subtitle = "Fly Together — A320 Cockpit Training"
        meta.type = .generic
        meta.supportsContinuationOnTV = false
        return meta
    }
}
