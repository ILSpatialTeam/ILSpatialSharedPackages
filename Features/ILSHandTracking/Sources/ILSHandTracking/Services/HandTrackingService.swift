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
    private let logger = ILLogger(subsystem: .handTracking, category: "HandTrackingService")

    private let lock = NSLock()

    // Recreated on every start() — ARKit providers cannot be reused after stop().
    private var session: ARKitSession?
    private var handTracking: HandTrackingProvider?
    private var updateTask: Task<Void, Never>?

    private var _isTracking = false
    public var isTracking: Bool {
        lock.withLock { _isTracking }
    }

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

        let newSession = ARKitSession()
        let newProvider = HandTrackingProvider()

        let authorizationResult = await newSession.requestAuthorization(for: [.handTracking])
        for (providerType, status) in authorizationResult {
            if status != .allowed {
                logger.warning("Authorization for \(providerType) denied or not determined.")
                return
            }
        }

        try await newSession.run([newProvider])

        lock.withLock {
            session = newSession
            handTracking = newProvider
            _isTracking = true
        }
        logger.info("Hand Tracking Started")

        updateTask = Task {
            for await update in newProvider.anchorUpdates {
                let anchor = update.anchor
                if anchor.chirality == .left {
                    self.lock.withLock { self._latestLeftHand = anchor }
                } else if anchor.chirality == .right {
                    self.lock.withLock { self._latestRightHand = anchor }
                }
            }
        }
    }

    public func stop() {
        updateTask?.cancel()
        updateTask = nil
        lock.withLock {
            session?.stop()
            session = nil
            handTracking = nil
            _isTracking = false
            _latestLeftHand = nil
            _latestRightHand = nil
        }
        logger.info("Hand Tracking Stopped")
    }
}
