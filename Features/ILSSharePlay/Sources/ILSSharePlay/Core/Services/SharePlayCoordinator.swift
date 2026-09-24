import Foundation
import GroupActivities
import Combine
import OSLog
import ILSFoundation
import CockpitDomain

@MainActor
@Observable
public final class SharePlayCoordinator: CockpitSharePlayBridge {
    private static let maxParticipants = 4
    private let logger = Logger(subsystem: "id.infinitelearning.airbus", category: "SharePlayCoordinator")

    public private(set) var isSharing: Bool = false
    public private(set) var isCockpitMode: Bool = false
    public private(set) var participants: [CockpitParticipant] = []
    public private(set) var errorMessage: String?

    #if targetEnvironment(simulator)
    public var isSimulatorSeatingPreviewEnabled = true {
        didSet { updateSpatialTemplate() }
    }
    #endif

    /// Mock FaceTime Personas are not app clients. Never relax reservations
    /// when another ALI client has joined, even in a simulator build.
    public var isSimulatorSeatingPreviewActive: Bool {
        #if targetEnvironment(simulator)
        return isSimulatorSeatingPreviewEnabled && localParticipant != nil
            && !participants.contains(where: { !$0.isLocal })
        #else
        return false
        #endif
    }

    public var isConnected: Bool { isSharing }

    public var localParticipant: CockpitParticipant? {
        participants.first(where: \.isLocal)
    }

    public var localRole: SessionRole {
        localParticipant?.role ?? .pilot
    }

    public var isPilotAuthority: Bool {
        localRole == .pilot
    }

    public var availableRoles: [SessionRole] {
        let occupied = Set(participants.map(\.role))
        return SessionRole.allCases.filter { !occupied.contains($0) }
    }

    private var session: GroupSession<CockpitGroupActivity>?
    private var messenger: GroupSessionMessenger?
    private var systemCoordinator: SystemCoordinator?
    private var spatialSeats: [CockpitRole: SIMD3<Float>] = [:]
    private var roleClaims: [String: SessionRole] = [:]
    private var rolesAreLocked = false
    private var messageTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var localParticipantID: String = UUID().uuidString

    private var incomingMessageBuffer: [CockpitGroupMessage] = []
    private var lastSentThrottle: Float = -1.0

    public var onRemoteLaunchRequested: ((AppLaunchMode) -> Void)?
    public var onRemoteExitRequested: (() -> Void)?

    /// Weak reference to the latest GameStateCore supplied by the immersive
    /// view's tick-loop. Used to push a full-state snapshot to late joiners
    /// so they don't start at cold-dark when the host is already mid-flight.
    private weak var cachedGameState: GameStateCore?

    public init() {}

    // MARK: - Session Lifecycle

    public func startListening() async {
        for await newSession in CockpitGroupActivity.sessions() {
            await configureSession(newSession)
        }
    }

    public func activate() async {
        do {
            let accepted = try await CockpitGroupActivity().activate()
            if accepted {
                // Session arrives through startListening()'s CockpitGroupActivity.sessions() loop.
                logger.info("SharePlay activity accepted — awaiting session via startListening()")
            } else {
                logger.info("SharePlay activation cancelled by user")
            }
        } catch {
            logger.error("SharePlay activation error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    public func leave() {
        if localRole == .pilot {
            session?.end()
        } else {
            session?.leave()
        }
        subscriptions.removeAll()
        messageTask?.cancel()
        messageTask = nil
        roleClaims.removeAll()
        rolesAreLocked = false
        spatialSeats.removeAll()
        session = nil
        messenger = nil
        systemCoordinator = nil
        isSharing = false
        isCockpitMode = false
        participants.removeAll()
        incomingMessageBuffer.removeAll()
        lastSentThrottle = -1.0
        logger.info("Left SharePlay session")
    }

    private func configureSession(_ newSession: GroupSession<CockpitGroupActivity>) async {
        if session != nil { leave() }
        self.session = newSession
        let messenger = GroupSessionMessenger(session: newSession)
        self.messenger = messenger

        setupMessageListeners(messenger: messenger)
        setupParticipantListeners(session: newSession)

        if let coordinator = await newSession.systemCoordinator {
            self.systemCoordinator = coordinator
            var configuration = SystemCoordinator.Configuration()
            configuration.supportsGroupImmersiveSpace = true
            // Fix 6: Start with sideBySide so the intro window isn't displaced.
            // enterCockpitMode() switches to CockpitSpatialTemplate after the
            // immersive space successfully opens.
            configuration.spatialTemplatePreference = .sideBySide
            coordinator.configuration = configuration
        }

        localParticipantID = newSession.localParticipant.id.uuidString
        newSession.join()
        isSharing = true

        // Ensure local participant is immediately added to avoid empty lobby
        let localID = newSession.localParticipant.id.uuidString
        if !participants.contains(where: { $0.id == localID }) {
            let initialRole: SessionRole = availableRoles.first ?? .pilot
            participants.append(CockpitParticipant(
                id: localID,
                role: initialRole,
                displayName: "You",
                isLocal: true
            ))
            localParticipantID = localID
        }

        resolveRoles()
        logger.info("Joined SharePlay session")
    }

    // MARK: - Spatial placement

    public func configureSpatialSeats(_ positions: [CockpitRole: SIMD3<Float>]) {
        spatialSeats = positions
        updateSpatialTemplate()
    }

    public func enterCockpitMode() {
        // Pin the settled lobby roster so later membership changes do not
        // reshuffle automatic seats while people are inside the cockpit.
        for participant in participants { roleClaims[participant.id] = participant.role }
        rolesAreLocked = true
        isCockpitMode = true
        updateSpatialTemplate()
    }

    private func updateSpatialTemplate() {
        guard isCockpitMode, spatialSeats.count == SessionRole.allCases.count,
              let systemCoordinator, let localParticipant else { return }
        systemCoordinator.configuration.spatialTemplatePreference = .custom(
            CockpitSpatialTemplate(
                positions: spatialSeats,
                previewRole: isSimulatorSeatingPreviewActive ? localParticipant.role : nil
            )
        )
        systemCoordinator.assignRole(localParticipant.role)
        logger.info("Assigned spatial seat: \(localParticipant.role.rawValue)")
    }

    public func leaveCockpitMode() {
        isCockpitMode = false
        rolesAreLocked = false
        systemCoordinator?.resignRole()
        systemCoordinator?.configuration.spatialTemplatePreference = .sideBySide
        spatialSeats.removeAll()
    }

    private func setupMessageListeners(messenger: GroupSessionMessenger) {
        messageTask = Task { [weak self] in
            for await (message, context) in messenger.messages(of: CockpitGroupMessage.self) {
                guard let self, !Task.isCancelled else { return }
                // A participant can claim only their own role.
                if case .roleAssigned(let id, _) = message,
                   id != context.source.id.uuidString { continue }
                self.handleIncomingMessage(message)
            }
        }
    }

    private func setupParticipantListeners(session: GroupSession<CockpitGroupActivity>) {
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                Task { @MainActor [weak self] in
                    guard self?.session === session else { return }
                    self?.reconcileParticipants(activeParticipants)
                }
            }
            .store(in: &subscriptions)

        session.$state
            .sink { [weak self] state in
                if case .invalidated = state {
                    Task { @MainActor [weak self] in
                        guard self?.session === session else { return }
                        self?.leave()
                    }
                }
            }
            .store(in: &subscriptions)
    }

    private func reconcileParticipants(_ activeParticipants: Set<Participant>) {
        let currentIDs = Set(participants.map(\.id))
        let activeIDs = Set(activeParticipants.map { $0.id.uuidString })

        // --- Handle departures ---
        let removedIDs = currentIDs.subtracting(activeIDs)
        if !removedIDs.isEmpty {
            // Protect local participant from being accidentally purged by a delayed activeParticipants update
            participants.removeAll { removedIDs.contains($0.id) && !$0.isLocal }
            for id in removedIDs where id != localParticipantID { roleClaims[id] = nil }
        }

        // --- Handle arrivals ---
        let newParticipants = activeParticipants
            .filter { !currentIDs.contains($0.id.uuidString) }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        for participant in newParticipants {
            if participants.count >= Self.maxParticipants {
                logger.warning("Participant \(participant.id.uuidString) rejected: max 4 reached")
                continue
            }

            let pid = participant.id.uuidString
            let isLocal = participant.id == session?.localParticipant.id

            let newP = CockpitParticipant(
                id: pid,
                role: .pilot, // Resolved for the complete roster below.
                displayName: isLocal ? "You" : "Participant \(participants.count + 1)",
                isLocal: isLocal
            )
            participants.append(newP)

            if isLocal {
                localParticipantID = pid
            }
        }

        resolveRoles()
        // Replay explicit lobby choices to late joiners. Keep claims even when
        // their message arrives before the participant publisher update.
        if !newParticipants.isEmpty, let claim = roleClaims[localParticipantID] {
            Task { await send(.roleAssigned(participantID: localParticipantID, role: claim)) }
        }

        // If local is Pilot, push the current state to the session so the new participant receives it
        if isPilotAuthority && !newParticipants.isEmpty, let gameState = cachedGameState {
            Task { await sendFullStateSnapshot(gameState: gameState) }
        }
    }

    // MARK: - Role Swap

    public func requestRoleSwap(to newRole: SessionRole) {
        guard !rolesAreLocked, availableRoles.contains(newRole),
              localParticipant != nil else { return }
        roleClaims[localParticipantID] = newRole
        resolveRoles()

        print("[SharePlayCoordinator] Requesting Role Swap to \(newRole.rawValue)")

        Task {
            await send(.roleAssigned(participantID: localParticipantID, role: newRole))
        }
    }

    private func resolveRoles() {
        let assignments = SessionRole.assignments(
            participantIDs: participants.map(\.id), claims: roleClaims
        )
        for index in participants.indices {
            if let role = assignments[participants[index].id] {
                participants[index].role = role
            }
        }
        participants.sort { $0.role.priority < $1.role.priority }
        updateSpatialTemplate()
    }

    // MARK: - Sending

    public func send(_ message: CockpitGroupMessage) async {
        guard let messenger else { return }
        do {
            try await messenger.send(message)
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
        }
    }

    /// Broadcast the shared cockpit preparation state.
    public func broadcastCockpitPrepChanged(_ prep: CockpitPrep) async {
        guard isSharing else { return }
        await send(.cockpitPrepChanged(prep))
    }

    public func cacheGameState(_ gameState: GameStateCore) {
        self.cachedGameState = gameState
    }

    public func sendFullStateSnapshot(gameState: GameStateCore) async {
        let snapshot = CockpitGroupMessage.fullStateSnapshot(
            switches: gameState.controls.switches,
            buttons: gameState.controls.buttons,
            knobs: gameState.controls.knobs,
            throttle: gameState.controls.throttle,
            cockpitPrep: gameState.cockpitPrep.current,
            sopStepIndex: gameState.sopStepIndex
        )
        await send(snapshot)
    }

    public func broadcastLaunchSimulation(_ mode: AppLaunchMode) async {
        guard isSharing else { return }
        let roles = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0.role) })
        await send(.launchSimulation(mode, roles: roles))
    }

    public func broadcastExitSimulation() async {
        guard isSharing else { return }
        await send(.exitSimulation)
    }

    public func requestFullStateSnapshot() async {
        guard isSharing else { return }
        await send(.requestFullStateSnapshot)
    }

    // MARK: - Incoming Message Handling

    private func handleIncomingMessage(_ message: CockpitGroupMessage) {
        switch message {
        case .roleAssigned(let pid, let role):
            guard !rolesAreLocked else { break }
            roleClaims[pid] = role
            resolveRoles()
        case .syncJoinOrder(let order):
            // Deprecated network message
            break
        case .heartbeat:
            break
        case .launchSimulation(let mode, let roles):
            // Launch carries the pilot's full roster, so delayed lobby updates
            // cannot make clients enter with different roles.
            roleClaims = roles
            rolesAreLocked = true
            resolveRoles()
            onRemoteLaunchRequested?(mode)
        case .exitSimulation:
            onRemoteExitRequested?()
        case .requestFullStateSnapshot:
            if isPilotAuthority, let gameState = cachedGameState {
                Task { await sendFullStateSnapshot(gameState: gameState) }
            }
        default:
            incomingMessageBuffer.append(message)
        }
    }

    public func consumeIncomingMessages() -> [CockpitGroupMessage] {
        let messages = incomingMessageBuffer
        incomingMessageBuffer.removeAll()
        return messages
    }

    // MARK: - Applying Messages to GameStateCore

    public func applyIncoming(_ message: CockpitGroupMessage, to gameState: GameStateCore) {
        switch message {
        case .switchChanged(let name, let state):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteSwitch(state, for: name)
            gameState.needsEntityReset = false
            gameState._pendingEntityStateResync = true
        case .buttonChanged(let name, let isOn):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteButton(isOn, for: name)
            gameState._pendingEntityStateResync = true
        case .knobChanged(let name, let index):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteKnob(index, for: name)
            gameState._pendingEntityStateResync = true
        case .throttleChanged(let value):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteThrottle(value)
            gameState._pendingEntityStateResync = true
        case .cockpitPrepChanged(let prep):
            gameState.cockpitPrep.transition(prep)
        case .sopStepChanged(let index):
            gameState.sopStepIndex = index
        case .fullStateSnapshot(let switches, let buttons, let knobs, let throttle, let prep, let sopStepIndex):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteFullState(
                switches: switches,
                buttons: buttons,
                knobs: knobs,
                throttle: throttle
            )
            gameState.sopStepIndex = sopStepIndex
            gameState.cockpitPrep.transition(prep)
            gameState._pendingEntityStateResync = true
        case .roleAssigned, .heartbeat, .syncJoinOrder, .launchSimulation, .exitSimulation, .requestFullStateSnapshot:
            break
        }
    }

    // MARK: - CockpitSharePlayBridge Conformance

    public func broadcastLocalChanges(_ deltas: [ControlChangeDelta]) async {
        guard isSharing else { return }
        for delta in deltas {
            let message: CockpitGroupMessage
            switch delta.kind {
            case .switchTo(let state):
                message = .switchChanged(entityName: delta.entityName, state: state)
            case .buttonTo(let isOn):
                message = .buttonChanged(entityName: delta.entityName, isOn: isOn)
            case .knobTo(let index):
                message = .knobChanged(entityName: delta.entityName, index: index)
            case .throttleTo(let value):
                let clamped = max(0, min(1, value))
                guard abs(clamped - lastSentThrottle) > 0.01 else { continue }
                lastSentThrottle = clamped
                message = .throttleChanged(clamped)
            case .sopStepTo(let index):
                message = .sopStepChanged(index)
            }
            await send(message)
        }
    }

    public func applyIncomingRemoteState(to gameState: GameStateCore) {
        guard isSharing else { return }
        // Fix 2: Cache a weak ref so reconcileParticipants can push a
        // full-state snapshot to late joiners without needing the view to
        // explicitly pass the gameState at join time.
        cachedGameState = gameState
        let messages = consumeIncomingMessages()
        guard !messages.isEmpty else { return }
        for message in messages {
            applyIncoming(message, to: gameState)
        }
    }
}
