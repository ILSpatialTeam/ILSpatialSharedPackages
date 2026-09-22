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

    public var isConnected: Bool { isSharing }

    public var localParticipant: CockpitParticipant? {
        participants.first(where: \.isLocal)
    }

    public var localRole: SessionRole {
        localParticipant?.role ?? .pilot
    }

    public var availableRoles: [SessionRole] {
        let occupied = Set(participants.map(\.role))
        return SessionRole.allCases.filter { !occupied.contains($0) }
    }

    private var session: GroupSession<CockpitGroupActivity>?
    private var messenger: GroupSessionMessenger?
    private var systemCoordinator: SystemCoordinator?   // Fix 6 + Fix 4
    private var subscriptions = Set<AnyCancellable>()
    private var localParticipantID: String = UUID().uuidString

    private var incomingMessageBuffer: [CockpitGroupMessage] = []
    private var lastSentThrottle: Float = -1.0

    /// Option B — cache the last-broadcast world-anchor offset so late joiners
    /// receive it when they connect mid-session.
    // (No longer tracking lastBroadcastOriginOffset)

    /// Ordered list of participant UUIDs in the sequence they were first
    /// observed by the host. Used to assign roles top-to-bottom (pilot first)
    /// in a stable, deterministic way across all devices.
    private var participantJoinOrder: [String] = []

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
        session?.leave()
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

            // Fix 4: Observe confirmed seat assignments from the OS.
            Task {
                for await state in coordinator.localParticipantStates {
                    logger.debug("Local participant seat updated: \(String(describing: state.seat))")
                }
            }
        }

        newSession.join()
        isSharing = true
        logger.info("Joined SharePlay session")
    }

    // MARK: - Fix 6: Cockpit Mode (deferred spatial template)

    /// Switch to the cockpit seat layout. Call this after the immersive space
    /// has successfully opened so the intro window is not displaced.
    public func enterCockpitMode() {
        isCockpitMode = true
        print("[SharePlayCoordinator] Entering Cockpit Mode. Local Role: \(localRole.rawValue)")
        print("[SharePlayCoordinator] Current Join Order: \(participantJoinOrder)")
        systemCoordinator?.configuration.spatialTemplatePreference = .custom(CockpitSpatialTemplate(participants: participants, joinOrder: participantJoinOrder))
        logger.info("Switched to dynamic CockpitSpatialTemplate based on join order")
    }

    /// Revert to side-by-side when returning to the intro screen.
    public func leaveCockpitMode() {
        isCockpitMode = false
        systemCoordinator?.configuration.spatialTemplatePreference = .sideBySide
        logger.info("Reverted to sideBySide template")
    }

    private func setupMessageListeners(messenger: GroupSessionMessenger) {
        Task { [weak self] in
            for await (message, _) in messenger.messages(of: CockpitGroupMessage.self) {
                guard let self else { return }
                await MainActor.run {
                    self.handleIncomingMessage(message)
                }
            }
        }
    }

    private func setupParticipantListeners(session: GroupSession<CockpitGroupActivity>) {
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                Task { @MainActor [weak self] in
                    self?.reconcileParticipants(activeParticipants)
                }
            }
            .store(in: &subscriptions)

        session.$state
            .sink { [weak self] state in
                if case .invalidated = state {
                    Task { @MainActor [weak self] in
                        self?.leave()
                    }
                }
            }
            .store(in: &subscriptions)
    }

    // MARK: - Host Detection (Fix 3)

    /// True on the device that should be authoritative for role assignment.
    /// Deterministic: the participant whose UUID string is lexicographically
    /// smallest is always the host on every device simultaneously, with no
    /// negotiation needed.
    private var isHost: Bool {
        guard let session else { return false }
        let localID = session.localParticipant.id.uuidString
        let allIDs = session.activeParticipants.map { $0.id.uuidString }
        return localID == (allIDs.min() ?? localID)
    }

    /// Option B — true when the local participant holds the Pilot role and
    /// should broadcast the ARKit world-anchor offset to peers.
    public var isPilotAuthority: Bool {
        localRole == .pilot
    }

    private func reconcileParticipants(_ activeParticipants: Set<Participant>) {
        let currentIDs = Set(participants.map(\.id))
        let activeIDs = Set(activeParticipants.map { $0.id.uuidString })

        // --- Handle departures ---
        let removedIDs = currentIDs.subtracting(activeIDs)
        if !removedIDs.isEmpty {
            // Replace with empty string to preserve slot indices for the OS spatial template
            for id in removedIDs {
                if let idx = participantJoinOrder.firstIndex(of: id) {
                    participantJoinOrder[idx] = ""
                }
            }
            participants.removeAll { removedIDs.contains($0.id) }
            // Host re-broadcasts updated roles after a departure.
            if isHost { promoteRolesIfNeeded() }
        }

        // --- Handle arrivals ---
        // Sort by UUID for a stable insertion order on every device.
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

            // Track join order so the host can assign the right slot.
            if !participantJoinOrder.contains(pid) {
                if let emptyIdx = participantJoinOrder.firstIndex(of: "") {
                    participantJoinOrder[emptyIdx] = pid
                } else {
                    participantJoinOrder.append(pid)
                }
            }

            // Fix 3: Non-hosts start with a .pilot placeholder and wait for
            // the host's roleAssigned message to apply the correct role.
            // The host assigns a definitive role immediately and broadcasts it.
            let usedRoles = Set(participants.map(\.role))
            let assignedRole = SessionRole.allCases.first(where: { !usedRoles.contains($0) }) ?? .instructor2

            let newP = CockpitParticipant(
                id: pid,
                role: isHost ? assignedRole : .pilot,   // non-hosts use placeholder
                displayName: isLocal ? "You" : "Participant \(participants.count + 1)",
                isLocal: isLocal
            )
            participants.append(newP)

            if isLocal {
                localParticipantID = pid
            }

            if isHost {
                // Host is the single authority: broadcast this participant's role
                // so every device (including the joiner) receives one definitive
                // assignment with no last-write-wins race.
                let role = assignedRole
                let updatedOrder = participantJoinOrder
                Task { 
                    await send(.roleAssigned(participantID: pid, role: role))
                    await send(.syncJoinOrder(updatedOrder))
                }

                // Fix 2: Push the current cockpit state to the new peer so they
                // don't land at cold-dark when the session is already mid-flight.
                if !isLocal, let gs = cachedGameState {
                    Task { await sendFullStateSnapshot(gameState: gs) }
                }
            }
        }

        participants.sort { $0.role.priority < $1.role.priority }
        
        // Fix: Update spatial template on the host and all peers if the participant list or order changed.
        if isCockpitMode {
            print("[SharePlayCoordinator] Re-evaluating template after participant change with Join Order: \(participantJoinOrder)")
            systemCoordinator?.configuration.spatialTemplatePreference = .custom(CockpitSpatialTemplate(participants: participants, joinOrder: participantJoinOrder))
        }
    }

    /// Called by the host only after a participant leaves.
    /// Re-packs remaining participants into contiguous top-priority slots
    /// (e.g. if Pilot leaves, Copilot → Pilot, Instructor1 → Copilot).
    /// The host broadcasts every reassignment so remote HUDs stay consistent.
    private func promoteRolesIfNeeded() {
        // Rebuild join-order-based roles using only the participants that remain.
        let sorted = participants.sorted { $0.role < $1.role }
        let targetRoles = Array(SessionRole.allCases.prefix(sorted.count))

        for (newRole, participant) in zip(targetRoles, sorted) {
            guard let idx = participants.firstIndex(where: { $0.id == participant.id }) else { continue }
            if participants[idx].role != newRole {
                participants[idx].role = newRole
                // Host broadcasts all promotions (not just local ones) so every
                // peer updates their HUD without another race.
                let pid = participants[idx].id
                Task { await send(.roleAssigned(participantID: pid, role: newRole)) }
            }
        }
    }

    // MARK: - Role Swap

    public func requestRoleSwap(to newRole: SessionRole) {
        guard availableRoles.contains(newRole),
              let localIdx = participants.firstIndex(where: \.isLocal) else { return }
        participants[localIdx].role = newRole
        
        print("[SharePlayCoordinator] Requesting Role Swap to \(newRole.rawValue)")
        print("[SharePlayCoordinator] Re-evaluating template with Join Order: \(participantJoinOrder)")
        
        // Tell the OS to re-evaluate the spatial template with the new role ordering
        systemCoordinator?.configuration.spatialTemplatePreference = .custom(CockpitSpatialTemplate(participants: participants, joinOrder: participantJoinOrder))
        
        Task {
            await send(.roleAssigned(participantID: localParticipantID, role: newRole))
        }
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

    /// Option B — pilot broadcasts the ARKit head-tracking world-anchor offset.
    /// Caches the value so late-joiners receive it when they connect.
    public func broadcastCockpitPrepChanged(_ prep: CockpitPrep) async {
        guard isSharing else { return }
        await send(.cockpitPrepChanged(prep))
    }

    public func sendFullStateSnapshot(gameState: GameStateCore) async {
        let snapshot = CockpitGroupMessage.fullStateSnapshot(
            switches: gameState.controls.switches,
            buttons: gameState.controls.buttons,
            knobs: gameState.controls.knobs,
            throttle: gameState.controls.throttle,
            cockpitPrep: gameState.cockpitPrep.current
        )
        await send(snapshot)
    }

    // MARK: - Incoming Message Handling

    private func handleIncomingMessage(_ message: CockpitGroupMessage) {
        switch message {
        case .roleAssigned(let pid, let role):
            if let idx = participants.firstIndex(where: { $0.id == pid }) {
                participants[idx].role = role
                participants.sort { $0.role.priority < $1.role.priority }
                
                // If the host assigned us a new role over the network, update the spatial template
                if participants[idx].isLocal {
                    print("[SharePlayCoordinator] Role updated to \(role.rawValue) by Host. Re-evaluating template.")
                    systemCoordinator?.configuration.spatialTemplatePreference = .custom(CockpitSpatialTemplate(participants: participants, joinOrder: participantJoinOrder))
                }
            }
        case .syncJoinOrder(let order):
            guard !isHost else { return }
            print("[SharePlayCoordinator] Received canonical join order from host: \(order)")
            participantJoinOrder = order
            // Re-evaluate template with the definitive join order
            systemCoordinator?.configuration.spatialTemplatePreference = .custom(CockpitSpatialTemplate(participants: participants, joinOrder: participantJoinOrder))
        case .heartbeat:
            break
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
        case .fullStateSnapshot(let switches, let buttons, let knobs, let throttle, let prep):
            gameState.actionSource = .remote
            gameState.controls.applyRemoteFullState(
                switches: switches,
                buttons: buttons,
                knobs: knobs,
                throttle: throttle
            )
            gameState.cockpitPrep.transition(prep)
            gameState._pendingEntityStateResync = true
        case .roleAssigned, .heartbeat, .syncJoinOrder:
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
