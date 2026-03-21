import Foundation
import Testing
@testable import traders_guild

@MainActor
struct ChatSurfaceOverlayCoordinatorTests {
    @Test
    func presentingMessageActionsDismissesComposerPanel() {
        let coordinator = ChatSurfaceOverlayCoordinator()
        let messageID = UUID()

        coordinator.setComposerActionPanelVisible(true)
        coordinator.presentActions(for: messageID)

        #expect(coordinator.presentation == .messageActions(messageID: messageID))
        #expect(coordinator.isComposerActionPanelVisible == false)
    }

    @Test
    func showingComposerPanelDismissesActiveMessageActions() {
        let coordinator = ChatSurfaceOverlayCoordinator()
        let messageID = UUID()

        coordinator.presentActions(for: messageID)
        coordinator.setComposerActionPanelVisible(true)

        #expect(coordinator.presentation == nil)
        #expect(coordinator.isComposerActionPanelVisible == true)
    }

    @Test
    func dismissAllClearsMessageActionsAndComposerPanel() {
        let coordinator = ChatSurfaceOverlayCoordinator()
        let messageID = UUID()

        coordinator.presentActions(for: messageID)
        coordinator.setComposerActionPanelVisible(true)
        coordinator.dismissAll()

        #expect(coordinator.presentation == nil)
        #expect(coordinator.isComposerActionPanelVisible == false)
    }

    @Test
    func presentingReactorsDismissesComposerPanel() {
        let coordinator = ChatSurfaceOverlayCoordinator()
        let messageID = UUID()

        coordinator.setComposerActionPanelVisible(true)
        coordinator.presentReactionReactors(for: messageID, emoji: "🔥")

        #expect(coordinator.presentation == .reactionReactors(messageID: messageID, emoji: "🔥"))
        #expect(coordinator.isComposerActionPanelVisible == false)
    }
}
