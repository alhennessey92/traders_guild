import Combine
import Foundation

enum ChatSurfaceOverlayPresentation: Equatable {
    case messageActions(messageID: UUID)
    case reactionReactors(messageID: UUID, reactions: [RLMessageReactionDTO])
}

struct ChatReactionReactorsState: Equatable {
    var messageID: UUID?
    /// Responses keyed by emoji
    var responses: [String: RLMessageReactionReactorsDTO] = [:]
    /// Which emojis are currently loading
    var loadingEmojis: Set<String> = []

    func matches(messageID: UUID) -> Bool {
        self.messageID == messageID
    }

    func response(for emoji: String) -> RLMessageReactionReactorsDTO? {
        responses[emoji]
    }

    func isLoading(emoji: String) -> Bool {
        loadingEmojis.contains(emoji)
    }
}

@MainActor
final class ChatSurfaceOverlayCoordinator: ObservableObject {
    @Published private(set) var presentation: ChatSurfaceOverlayPresentation?
    @Published private(set) var isComposerActionPanelVisible = false

    func presentActions(for messageID: UUID) {
        presentation = .messageActions(messageID: messageID)
        isComposerActionPanelVisible = false
    }

    func presentReactionReactors(for messageID: UUID, reactions: [RLMessageReactionDTO]) {
        presentation = .reactionReactors(messageID: messageID, reactions: reactions)
        isComposerActionPanelVisible = false
    }

    func dismissMessageActions() {
        if case .messageActions = presentation {
            presentation = nil
        }
    }

    func dismissOverlay() {
        presentation = nil
    }

    func setComposerActionPanelVisible(_ isVisible: Bool) {
        if isVisible {
            presentation = nil
        }
        isComposerActionPanelVisible = isVisible
    }

    func dismissAll() {
        presentation = nil
        isComposerActionPanelVisible = false
    }

    func isPresentingActions(for messageID: UUID) -> Bool {
        guard case let .messageActions(activeMessageID) = presentation else { return false }
        return activeMessageID == messageID
    }

    func isPresentingReactionReactors(for messageID: UUID) -> Bool {
        guard case let .reactionReactors(activeMessageID, _) = presentation else { return false }
        return activeMessageID == messageID
    }
}
