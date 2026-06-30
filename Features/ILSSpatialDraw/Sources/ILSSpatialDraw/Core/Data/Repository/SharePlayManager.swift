import Foundation
import GroupActivities
import Combine
import ILSFoundation

@MainActor
public class SharePlayManager: ILSharePlayManager<DrawingActivity>, ObservableObject, DrawingSharePlayProvider {
    
    // Buffer for ECS system to consume (Accessed only on MainActor)
    private var remoteStrokeBuffer: [StrokeMessage] = []
    
    public override init() {
        super.init()
    }
    
    public func consumeRemoteStrokes() -> [StrokeMessage] {
        let messages = remoteStrokeBuffer
        remoteStrokeBuffer.removeAll()
        return messages
    }
    
    // For the AsyncStream of incoming strokes
    private var strokeContinuation: AsyncStream<StrokeMessage>.Continuation?
    lazy var incomingStrokes: AsyncStream<StrokeMessage> = {
        AsyncStream { continuation in
            self.strokeContinuation = continuation
        }
    }()
    
    public func activateActivity() async {
        await super.activateActivity(DrawingActivity())
    }
    
    public override func setupMessageListeners(messenger: GroupSessionMessenger) {
        // Listen for strokes from others
        Task {
            for await (message, _) in messenger.messages(of: StrokeMessage.self) {
                // Since this Task inherits MainActor, we call it directly
                self.receiveMessage(message)
            }
        }
    }
    
    /// Internal helper to update buffer on MainActor
    private func receiveMessage(_ message: StrokeMessage) {
        self.remoteStrokeBuffer.append(message)
        self.strokeContinuation?.yield(message)
    }
    
    public func sendStroke(_ message: StrokeMessage) async {
        await super.send(message)
    }
}
