import CoreGraphics
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
        let reactions = [RLMessageReactionDTO(emoji: "🔥", count: 3, reactedByCurrentUser: true)]

        coordinator.setComposerActionPanelVisible(true)
        coordinator.presentReactionReactors(for: messageID, reactions: reactions)

        #expect(coordinator.presentation == .reactionReactors(messageID: messageID, reactions: reactions))
        #expect(coordinator.isComposerActionPanelVisible == false)
    }

    @Test
    func presentingAnotherOverlayKeepsComposerPanelDismissedAndReplacesPreviousOverlay() {
        let coordinator = ChatSurfaceOverlayCoordinator()
        let firstMessageID = UUID()
        let secondMessageID = UUID()
        let reactions = [RLMessageReactionDTO(emoji: "🚀", count: 2, reactedByCurrentUser: false)]

        coordinator.setComposerActionPanelVisible(true)
        coordinator.presentReactionReactors(for: firstMessageID, reactions: reactions)
        coordinator.presentActions(for: secondMessageID)

        #expect(coordinator.presentation == .messageActions(messageID: secondMessageID))
        #expect(coordinator.isComposerActionPanelVisible == false)
    }

    @Test
    func chatFooterLayoutDoesNotAddExtraBottomPaddingWhenKeyboardIsVisible() {
        let layout = KeyboardPinnedFooterLayout.resolve(
            mode: .chat,
            geometryBottomInset: 336,
            hardwareBottomInset: 34
        )

        #expect(layout.footerBottomPadding == 0)
    }

    @Test
    func chatFooterLayoutUsesLoweredHardwareInsetWhenKeyboardIsHidden() {
        let layout = KeyboardPinnedFooterLayout.resolve(
            mode: .chat,
            geometryBottomInset: 34,
            hardwareBottomInset: 34
        )

        #expect(layout.footerBottomPadding == 6)
    }

    @Test
    func attachmentPanelOffsetTracksComposerMetrics() {
        #expect(
            ChatComposerLayoutMetrics.attachmentPanelBottomOffset
            == ChatComposerLayoutMetrics.barHeight
                + ChatComposerLayoutMetrics.containerVerticalPadding
                + ChatComposerLayoutMetrics.attachmentPanelGap
        )
        #expect(ChatComposerLayoutMetrics.attachmentPanelBottomOffset == 64)
    }
}
