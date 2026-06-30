import RealityKit

/// ECS component attached to the canvas to handle incoming SharePlay strokes
public struct SharePlayReceiverComponent: Component {
    public weak var manager: (any DrawingSharePlayProvider)?
    
    public init(manager: any DrawingSharePlayProvider) {
        self.manager = manager
    }
}
