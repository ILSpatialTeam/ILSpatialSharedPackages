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

    private var startGeneration: UUID?

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

        let generation = UUID()
        let ownsStart = lock.withLock {
            guard startGeneration == nil else { return false }
            startGeneration = generation
            return true
        }
        guard ownsStart else { return }

        let newSession = ARKitSession()
        let newProvider = HandTrackingProvider()
        do {
            let authorization = await newSession.requestAuthorization(for: [.handTracking])
            try Task.checkCancellation()
            guard authorization.values.allSatisfy({ $0 == .allowed }) else {
                lock.withLock {
                    if startGeneration == generation { startGeneration = nil }
                }
                return
            }
            // stop() may have invalidated this start while authorization was open.
            let shouldRun = lock.withLock {
                guard startGeneration == generation else { return false }
                session = newSession
                handTracking = newProvider
                return true
            }
            guard shouldRun else { return }
            try await newSession.run([newProvider])
            try Task.checkCancellation()

            let installed = lock.withLock {
                guard startGeneration == generation else { return false }
                _isTracking = true
                updateTask = Task { [weak self] in
                    for await update in newProvider.anchorUpdates {
                        guard !Task.isCancelled, let self else { break }
                        let accepted = self.lock.withLock {
                            guard self.startGeneration == generation else { return false }
                            let anchor = update.anchor
                            if anchor.chirality == .left {
                                self._latestLeftHand = anchor
                            } else if anchor.chirality == .right {
                                self._latestRightHand = anchor
                            }
                            return true
                        }
                        if !accepted { break }
                    }
                }
                return true
            }
            if installed {
                logger.info("Hand Tracking Started")
            } else {
                newSession.stop()
            }
        } catch {
            newSession.stop()
            lock.withLock {
                // An older start must never clear a newer session.
                if startGeneration == generation {
                    startGeneration = nil
                    session = nil
                    handTracking = nil
                    _isTracking = false
                }
            }
            throw error
        }
    }

    public func stop() {
        let resources = lock.withLock {
            let resources = (updateTask, session)
            startGeneration = nil
            updateTask = nil
            session = nil
            handTracking = nil
            _isTracking = false
            _latestLeftHand = nil
            _latestRightHand = nil
            return resources
        }
        resources.0?.cancel()
        resources.1?.stop()
        logger.info("Hand Tracking Stopped")
    }
}
