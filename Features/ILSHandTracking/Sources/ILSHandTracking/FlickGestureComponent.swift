import RealityKit
import Foundation

/// Represents the direction of a detected hand flick.
public enum FlickDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

/// A component that stores the most recently detected directional flicks for an entity.
/// Systems can query this component to react to user flicks.
public struct FlickGestureComponent: Component {
    /// The most recently detected flick from the right hand
    public var lastRightFlick: FlickDirection?
    
    /// The most recently detected flick from the left hand
    public var lastLeftFlick: FlickDirection?
    
    /// The timestamp of the last detected flick to handle debouncing and frame lifetime
    public var lastFlickTime: TimeInterval = 0
    
    public init() {}
}
