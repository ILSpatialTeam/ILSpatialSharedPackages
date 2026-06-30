import Foundation
import ARKit
import ILSFoundation

public protocol HandTrackingServiceProtocol: SpatialServiceProtocol {
    var isTracking: Bool { get }
    var latestLeftHand: HandAnchor? { get }
    var latestRightHand: HandAnchor? { get }
}

public final class HandTrackingService: HandTrackingServiceProtocol, @unchecked Sendable {
    public static let shared = HandTrackingService()
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let logger = ILLogger(subsystem: .handTracking, category: "HandTrackingService")
    
    private let lock = NSLock()
    
    private var _isTracking = false
    public var isTracking: Bool {
        lock.withLock { _isTracking }
    }
    
    private var updateTask: Task<Void, Never>?
    
    private var _latestLeftHand: HandAnchor?
    public var latestLeftHand: HandAnchor? {
        lock.withLock { _latestLeftHand }
    }
    
    private var _latestRightHand: HandAnchor?
    public var latestRightHand: HandAnchor? {
        lock.withLock { _latestRightHand }
    }
    
    public init() {}
    
    public func start() async throws {
        guard HandTrackingProvider.isSupported else {
            logger.warning("Hand tracking not supported on this device.")
            return
        }
        
        let authorizationResult = await session.requestAuthorization(for: [.handTracking])
        for (providerType, status) in authorizationResult {
            if status != .allowed {
                logger.warning("Authorization for \(providerType) denied or not determined.")
                return
            }
        }
        
        try await session.run([handTracking])
        lock.withLock { _isTracking = true }
        logger.info("Hand Tracking Started")
        
        updateTask = Task {
            for await update in handTracking.anchorUpdates {
                let anchor = update.anchor
                if anchor.chirality == .left {
                    self.lock.withLock { self._latestLeftHand = anchor }
                } else if anchor.chirality == .right {
                    self.lock.withLock { self._latestRightHand = anchor }
                    if Int.random(in: 1...60) == 1 {
                        self.logger.info("Streaming right hand anchor: tracked=\(anchor.isTracked)")
                    }
                }
            }
        }
    }
    
    public func stop() {
        updateTask?.cancel()
        updateTask = nil
        session.stop()
        lock.withLock { _isTracking = false }
        logger.info("Hand Tracking Stopped")
    }
}
