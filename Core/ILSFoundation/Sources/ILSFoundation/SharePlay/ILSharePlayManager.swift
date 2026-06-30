import Foundation
import GroupActivities
import Combine
import OSLog

/// A generic manager that handles SharePlay session lifecycle and Spatial Personas.
/// Subclass this or compose it to handle specific Message types and Activities.
@MainActor
open class ILSharePlayManager<Activity: GroupActivity> {
    @Published public var isSharing: Bool = false
    public let localParticipantID = UUID()
    
    public private(set) var session: GroupSession<Activity>?
    public private(set) var messenger: GroupSessionMessenger?
    
    private var subscriptions = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.ilspatial.foundation", category: "ILSharePlayManager")
    
    public init() {}
    
    /// Start listening for new group sessions (e.g., when someone else starts SharePlay)
    open func startListening() async {
        for await newSession in Activity.sessions() {
            await configureSession(newSession)
        }
    }
    
    /// Activate a new SharePlay activity locally
    open func activateActivity(_ activity: Activity) async {
        do {
            _ = try await activity.activate()
            logger.info("Successfully activated SharePlay activity.")
        } catch {
            logger.error("Failed to activate SharePlay: \(error.localizedDescription)")
        }
    }
    
    /// Stop sharing and leave the current session
    open func stopSharing() {
        session?.leave()
        session = nil
        messenger = nil
        isSharing = false
        logger.info("Stopped sharing.")
    }
    
    /// Override this method to setup your message listeners using the messenger
    open func setupMessageListeners(messenger: GroupSessionMessenger) {
        // Subclasses should implement
    }
    
    private func configureSession(_ newSession: GroupSession<Activity>) async {
        self.session = newSession
        let messenger = GroupSessionMessenger(session: newSession)
        self.messenger = messenger
        
        // Setup custom message listeners
        setupMessageListeners(messenger: messenger)
        
        // Handle session state changes
        newSession.$state.sink { [weak self] state in
            if case .invalidated = state {
                Task { @MainActor in
                    self?.stopSharing()
                }
            }
        }
        .store(in: &subscriptions)
        
        // Enable Spatial Personas
        if let coordinator = await newSession.systemCoordinator {
            logger.info("Configuring SystemCoordinator for spatial personas")
            var configuration = SystemCoordinator.Configuration()
            configuration.supportsGroupImmersiveSpace = true
            configuration.spatialTemplatePreference = .sideBySide
            coordinator.configuration = configuration
        } else {
            logger.warning("SystemCoordinator NOT available - Spatial Personas may not work")
        }
        
        newSession.join()
        isSharing = true
    }
    
    /// Helper to send generic messages
    public func send<Message: Codable>(_ message: Message) async {
        guard let messenger = messenger else { return }
        do {
            try await messenger.send(message)
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
        }
    }
}
