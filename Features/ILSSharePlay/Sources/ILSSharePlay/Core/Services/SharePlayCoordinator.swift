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
    private var subscriptions = Set<AnyCancellable>()
    private var localParticipantID: String = UUID().uuidString

    private var incomingMessageBuffer: [CockpitGroupMessage] = []
    private var lastSentThrottle: Float = -1.0

    public init() {}

    // MARK: - Session Lifecycle

    public func startListening() async {
        for await newSession in CockpitGroupActivity.sessions() {
            await configureSession(newSession)
        }
    }

    public func activate() async {
        do {
            let result = try await CockpitGroupActivity().activate()
            switch result {
            case .success(let session):
                await configureSession(session)
            case .failure(let error):
                logger.error("Failed to activate SharePlay: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            case .cancelled:
                logger.info("SharePlay activation cancelled by user")
            @unknown default:
                break
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
        isSharing = false
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
            var configuration = SystemCoordinator.Configuration()
            configuration.supportsGroupImmersiveSpace = true
            configuration.spatialTemplatePreference = .sideBySide
            coordinator.configuration = configuration
        }

        newSession.join()
        isSharing = true
        logger.info("Joined SharePlay session")
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

    private func reconcileParticipants(_ activeParticipants: Set<Participant>) {
        let currentIDs = Set(participants.map(\.id))
        let activeIDs = Set(activeParticipants.map { $0.id.uuidString })

        let removedIDs = currentIDs.subtracting(activeIDs)
        if !removedIDs.isEmpty {
            participants.removeAll { removedIDs.contains($0.id) }
            promoteRolesIfNeeded()
        }

        let newParticipants = activeParticipants.filter { !currentIDs.contains($0.id.uuidString) }
        for participant in newParticipants {
            if participants.count >= Self.maxParticipants {
                logger.warning("Participant \(participant.id.uuidString) rejected: max 4 reached")
                continue
            }
            let isLocal = participant.id == session?.localParticipant.id
            let role = nextAvailableRole()
            let newP = CockpitParticipant(
                id: participant.id.uuidString,
                role: role,
                displayName: isLocal ? "You" : "Participant \(participants.count + 1)",
                isLocal: isLocal
            )
            participants.append(newP)
            if isLocal {
                localParticipantID = participant.id.uuidString
            }
            Task {
                await send(.roleAssigned(participantID: newP.id, role: role))
            }
        }

        participants.sort { $0.role.priority < $1.role.priority }
    }

    private func nextAvailableRole() -> SessionRole {
        let occupied = Set(participants.map(\.role))
        for role in SessionRole.allCases {
            if !occupied.contains(role) { return role }
        }
        return .instructor2
    }

    private func promoteRolesIfNeeded() {
        let occupied = Set(participants.map(\.role))
        for role in SessionRole.allCases {
            if !occupied.contains(role) {
                if let lowerIdx = participants.firstIndex(where: { $0.role > role }) {
                    participants[lowerIdx].role = role
                }
            }
        }
    }

    // MARK: - Role Swap

    public func requestRoleSwap(to newRole: SessionRole) {
        guard availableRoles.contains(newRole),
              let localIdx = participants.firstIndex(where: \.isLocal) else { return }
        participants[localIdx].role = newRole
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
            }
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
        case .roleAssigned, .heartbeat:
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
        let messages = consumeIncomingMessages()
        guard !messages.isEmpty else { return }
        for message in messages {
            applyIncoming(message, to: gameState)
        }
    }
}
