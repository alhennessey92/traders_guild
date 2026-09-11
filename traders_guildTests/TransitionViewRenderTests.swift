import Foundation
import SwiftUI
import Testing
import UIKit
@testable import traders_guild

/// Renders the transition overlay's two compositions to bitmaps.
///
/// The launch variant is easy to see in a simulator; the guild-operation
/// variant needs a second guild or a create/delete, which the disposable QA
/// account does not have and DEV data should not gain. Rendering the view
/// directly is the honest way to check both share one layout after the
/// consolidation, and it keeps a picture of each beside the test run.
@MainActor
struct TransitionViewRenderTests {

    /// Where the bitmaps go. `xcodebuild` runs tests on a throwaway simulator
    /// clone whose temp directory vanishes with it, so a reviewer who wants
    /// the pictures passes a host path as `TEST_RUNNER_TG_TRANSITION_RENDER_DIR`;
    /// otherwise they land in the runner's temp directory and only the
    /// assertions matter.
    private static let outputDirectory: URL = {
        if let custom = ProcessInfo.processInfo.environment["TG_TRANSITION_RENDER_DIR"],
           !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tg-transition-renders", isDirectory: true)
    }()

    private func render(_ request: GuildTransitionRequest, name: String) throws -> UIImage {
        let state = RLAppState(restoreSessionOnInit: false)
        let view = TransitionView(request: request)
            .environmentObject(state)
            .frame(width: 402, height: 874)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage, "\(name) did not render")

        // Into the result bundle, where it survives the simulator clone the
        // run happened on: `xcrun xcresulttool export attachments`.
        Attachment.record(image, named: "\(name).png")

        try FileManager.default.createDirectory(
            at: Self.outputDirectory, withIntermediateDirectories: true
        )
        let url = Self.outputDirectory.appendingPathComponent("\(name).png")
        try #require(image.pngData()).write(to: url)
        return image
    }

    @Test
    func launchRendersTheLogoComposition() throws {
        let image = try render(.launch(), name: "launch")
        #expect(image.size.width > 0 && image.size.height > 0)
    }

    @Test
    func eachGuildOperationRendersTheCrestComposition() throws {
        let entry = makeGuild(name: "Night Owls")
        for action in [GuildTransitionAction.creating, .joining, .deleting, .switching] {
            let image = try render(.guild(action, guild: entry), name: "guild-\(action)")
            #expect(image.size.width > 0)
        }
    }

    @Test
    func aGuildWithoutACrestRendersItsInitial() throws {
        let identity = GuildTransitionIdentity(
            id: UUID(), name: "Quiet Hours", imageURL: nil, crestSymbol: nil, crestColor: nil
        )
        let image = try render(
            GuildTransitionRequest(action: .joining, guild: identity), name: "guild-initial"
        )
        #expect(image.size.width > 0)
    }

    private func makeGuild(name: String) -> RLGuildDTO {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return RLGuildDTO(
            id: UUID(), name: name, slug: "night-owls", description: nil,
            imageUrl: nil, ownerId: UUID(), isOpen: true, isOnboardingSystemGuild: false,
            reputation: 0, memberCount: 3, membersOnline: 1, ownerDisplayName: nil,
            ownerUsername: nil, ownerAvatarUrl: nil, language: nil, location: nil,
            status: "active", dateCreated: now, updatedAt: now,
            crestSymbol: "bolt", crestColor: "gold", bannerUrl: nil, publicLeaderboard: nil
        )
    }
}
