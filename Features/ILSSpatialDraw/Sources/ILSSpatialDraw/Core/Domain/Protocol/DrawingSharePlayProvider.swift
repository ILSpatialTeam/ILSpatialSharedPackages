import Foundation
import ILSSharePlay

/// A draw-specific extension of the base SharePlay manager protocol.
public protocol DrawingSharePlayProvider: SharePlayManagerProtocol {
    func consumeRemoteStrokes() -> [StrokeMessage]
    func sendStroke(_ message: StrokeMessage) async
}
