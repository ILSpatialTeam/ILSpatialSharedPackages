import Foundation
import ARKit
import ILSFoundation
import QuartzCore
import os

public protocol HandTrackingServiceProtocol: SpatialServiceProtocol {
    var isTracking: Bool { get }
    var latestLeftHand: HandAnchor? { get }
    var latestRightHand: HandAnchor? { get }
}

public final class HandTrackingService: HandTrackingServiceProtocol, @unchecked Sendable {
    public static let shared = HandTrackingService()
    private let logger = ILLogger(subsystem: .handTracking, category: "HandTrackingService")

    private let lock = NSLock()
    private let signposter = OSSignposter(subsystem: "com.ali.handtracking", category: "HandLatency")

    // Recreated on every start() — ARKit providers cannot be reused after stop().
    private var session: ARKitSession?
    private var handTracking: HandTrackingProvider?
    private var worldTracking: WorldTrackingProvider?
    private var updateTask: Task<Void, Never>?

    private var startGeneration: UUID?

    private var _isTracking = false
    public var isTracking: Bool {
        lock.withLock { _isTracking }
    }

    private var handRevision: UInt64 = 0
    /// Atomic snapshot lets consumers build a pose once per ARKit update.
    public var handSnapshot: (revision: UInt64, left: HandAnchor?, right: HandAnchor?) {
        lock.withLock { (handRevision, _latestLeftHand, _latestRightHand) }
    }

    /// ARKit's timestamp query is not thread-safe; serialize it with provider lifecycle.
    /// This bypasses the async delivery queue for rendering without changing interaction samples.
    public func handsForRendering(at timestamp: TimeInterval) -> (left: HandAnchor?, right: HandAnchor?) {
        lock.withLock {
            guard timestamp.isFinite, _isTracking, let provider = handTracking,
                  provider.state == .running else { return (nil, nil) }
            let predicted = provider.handAnchors(at: timestamp)
            return (predicted.leftHand ?? _latestLeftHand, predicted.rightHand ?? _latestRightHand)
        }
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

    /// The same ARKit session owns hand and device tracking, so starting hand
    /// tracking cannot stop the provider used by the head-facing diagnostic.
    public func deviceTransform() -> simd_float4x4? {
        let provider = lock.withLock { _isTracking ? worldTracking : nil }
        guard provider?.state == .running,
              let anchor = provider?.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()),
              anchor.isTracked else { return nil }
        return anchor.originFromAnchorTransform
    }

    public func start() async throws {
        let canHandTrack = HandTrackingProvider.isSupported
        let canWorldTrack = WorldTrackingProvider.isSupported
        guard canHandTrack || canWorldTrack else {
            logger.warning("Hand and world tracking not supported on this device.")
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
        let newProvider = canHandTrack ? HandTrackingProvider() : nil
        let newWorldProvider = canWorldTrack ? WorldTrackingProvider() : nil
        do {
            if canHandTrack {
                let authorization = await newSession.requestAuthorization(for: [.handTracking])
                try Task.checkCancellation()
                guard authorization.values.allSatisfy({ $0 == .allowed }) else {
                    lock.withLock {
                        if startGeneration == generation { startGeneration = nil }
                    }
                    return
                }
            }
            // stop() may have invalidated this start while authorization was open.
            let shouldRun = lock.withLock {
                guard startGeneration == generation else { return false }
                session = newSession
                handTracking = newProvider
                worldTracking = newWorldProvider
                return true
            }
            guard shouldRun else { return }

            var providers: [any DataProvider] = []
            if let newProvider { providers.append(newProvider) }
            if let newWorldProvider { providers.append(newWorldProvider) }
            try await newSession.run(providers)
            try Task.checkCancellation()

            let installed = lock.withLock {
                guard startGeneration == generation else { return false }
                _isTracking = true
                if let newProvider {
                    updateTask = Task { [weak self] in
                        for await update in newProvider.anchorUpdates {
                            guard !Task.isCancelled, let self else { break }
                            let accepted = self.lock.withLock {
                                guard self.startGeneration == generation else { return false }
                                self.handRevision &+= 1
                                let anchor = update.anchor
                                if self.signposter.isEnabled {
                                    let age = max(0, CACurrentMediaTime() - update.timestamp) * 1000
                                    self.signposter.emitEvent("HandAnchorReceived", "sample_age_ms=\(age, privacy: .public)")
                                }
                                if anchor.chirality == .left {
                                    self._latestLeftHand = update.event == .removed ? nil : anchor
                                } else if anchor.chirality == .right {
                                    self._latestRightHand = update.event == .removed ? nil : anchor
                                }
                                return true
                            }
                            if !accepted { break }
                        }
                    }
                }
                return true
            }
            if installed {
                logger.info("Hand and World Tracking Started")
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
                    worldTracking = nil
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
            worldTracking = nil
            _isTracking = false
            handRevision &+= 1
            _latestLeftHand = nil
            _latestRightHand = nil
            return resources
        }
        resources.0?.cancel()
        resources.1?.stop()
        logger.info("Hand Tracking Stopped")
    }
}
