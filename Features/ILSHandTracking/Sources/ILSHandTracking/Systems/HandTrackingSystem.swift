import ARKit

public struct HandTrackingSystem {
    /// A globally accessible reference to the latest tracked right hand anchor.
    /// In a real app, this should be updated by a HandTrackingService observing ARKit session updates.
    public static var latestRightHand: HandAnchor?
    
    /// A globally accessible reference to the latest tracked left hand anchor.
    public static var latestLeftHand: HandAnchor?
}
