//
//  LeaderboardWindowSharingTests.swift
//  traders_guildTests
//
//  The windowed leaderboard contract and the copy that leaves the app with it.
//
//  Two things are worth pinning: that the new fields decode against a server
//  that does not yet send them (1.2.0's backend is live), and that a shared
//  standing says something specific enough to be worth posting.
//

import Testing
import Foundation
@testable import traders_guild

struct LeaderboardWindowSharingTests {

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Window vocabulary

    @Test func windowRawValuesMatchTheServersQueryVocabulary() {
        // These go straight into a URL, so a rename here is a wire change.
        #expect(LeaderboardWindow.week.rawValue == "7d")
        #expect(LeaderboardWindow.month.rawValue == "30d")
        #expect(LeaderboardWindow.all.rawValue == "all")
    }

    @Test func aShorterWindowAsksForFewerPredictions() {
        // A week's board at the all-time threshold would be empty for the
        // 50-500 member guilds this is aimed at.
        #expect(LeaderboardWindow.week.minimumPredictions < LeaderboardWindow.all.minimumPredictions)
        #expect(LeaderboardWindow.month.minimumPredictions < LeaderboardWindow.all.minimumPredictions)
    }

    // MARK: - Decoding

    @Test func leaderboardDecodesWithoutTheNewWindowFields() throws {
        // The live 1.2.0 backend predates windows; the app must not fail here.
        let json = """
        {
          "members": [],
          "total_members": 0,
          "min_predictions_threshold": 10
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RLAccuracyLeaderboardDTO.self, from: json)

        #expect(response.window == nil)
        #expect(response.symbolId == nil)
        #expect(response.minPredictionsThreshold == 10)
    }

    @Test func leaderboardCarriesTheWindowTheServerRankedOver() throws {
        let json = """
        {
          "members": [],
          "total_members": 3,
          "min_predictions_threshold": 1,
          "window": "7d",
          "symbol_id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E5F"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RLAccuracyLeaderboardDTO.self, from: json)

        #expect(response.window == "7d")
        #expect(response.symbolId != nil)
    }

    @Test func guildDecodesWithoutThePublicLeaderboardFlag() throws {
        let json = """
        {
          "id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E5F",
          "name": "Nocturne Capital",
          "slug": "nocturne",
          "description": null,
          "image_url": null,
          "owner_id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E60",
          "is_open": true,
          "reputation": 0,
          "member_count": 4,
          "members_online": 1,
          "status": "active",
          "date_created": "2026-09-01T00:00:00Z",
          "updated_at": "2026-09-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let guild = try decoder.decode(RLGuildDTO.self, from: json)

        // Absent means private, which is the safe reading.
        #expect(guild.publicLeaderboard == nil)
        #expect((guild.publicLeaderboard ?? false) == false)
    }

    @Test func discordChannelDecodesWithoutTheDigestFlag() throws {
        let json = """
        {
          "id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E5F",
          "guild_id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E60",
          "label": "signals",
          "webhook_masked": "https://discord.com/api/webhooks/1/••••abcd",
          "webhook_id": "123456789012345678",
          "is_default": true,
          "auto_post_markers": false,
          "status": "active",
          "consecutive_failures": 0,
          "created_at": "2026-09-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let channel = try decoder.decode(RLGuildDiscordChannelDTO.self, from: json)

        #expect(channel.postWeeklyDigest == nil)
        #expect(channel.canPost)
        #expect(channel.displayLabel == "#signals")
    }

    // MARK: - Share copy

    private func member(
        name: String, accuracy: Double, wins: Int, total: Int, rank: Int
    ) throws -> RLAccuracyLeaderboardMemberDTO {
        let json = """
        {
          "user_id": "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E5F",
          "username": "\(name)",
          "display_name": "\(name)",
          "avatar_url": null,
          "accuracy_rate": \(accuracy),
          "total_predictions": \(total),
          "successful_predictions": \(wins),
          "avg_rr_ratio": null,
          "rank": \(rank)
        }
        """.data(using: .utf8)!
        return try decoder.decode(RLAccuracyLeaderboardMemberDTO.self, from: json)
    }

    @Test func headlineNamesTheLeaderTheirRecordAndThePeriod() throws {
        let leader = try member(name: "alex", accuracy: 0.67, wins: 12, total: 18, rank: 1)

        let headline = LeaderboardShare.headline(
            guildName: "Nocturne Capital", window: .week, leader: leader
        )

        #expect(headline == "alex leads Nocturne Capital on 67% accuracy (12W · 6L) over the last 7 days.")
    }

    @Test func headlineStillReadsWhenNobodyIsRankedYet() {
        let headline = LeaderboardShare.headline(
            guildName: "Nocturne Capital", window: .month, leader: nil
        )

        #expect(headline == "Nocturne Capital · last 30 days accuracy standings")
    }

    @Test func aPublishedGuildSharesTheStandingsPageWithItsWindow() {
        let url = LeaderboardShare.publicURL(slug: "nocturne", window: .week)

        #expect(url?.absoluteString == "https://tradersguild.co/g/nocturne/leaderboard?window=7d")
    }

    @Test func theAllTimeBoardNeedsNoWindowInItsLink() {
        let url = LeaderboardShare.publicURL(slug: "nocturne", window: .all)

        #expect(url?.absoluteString == "https://tradersguild.co/g/nocturne/leaderboard")
    }

    @Test func aGuildWithoutAHandleHasNoPublicStandingsLink() {
        #expect(LeaderboardShare.publicURL(slug: nil, window: .week) == nil)
        #expect(LeaderboardShare.publicURL(slug: "", window: .week) == nil)
    }

    @Test func theSharedMessageCarriesTheLinkAndWhyItIsCredible() throws {
        let leader = try member(name: "alex", accuracy: 0.67, wins: 12, total: 18, rank: 1)
        let url = LeaderboardShare.publicURL(slug: "nocturne", window: .week)

        let message = LeaderboardShare.message(
            guildName: "Nocturne Capital", window: .week, leader: leader, url: url
        )

        #expect(message.contains("alex leads"))
        // The claim only lands because nobody chose which calls to count.
        #expect(message.contains("scored automatically"))
        #expect(message.contains("tradersguild.co/g/nocturne/leaderboard"))
    }

    @Test func theXComposerEscapesTheStandingsText() {
        let url = LeaderboardShare.xComposeURL(text: "alex leads on 67% accuracy & counting")

        let raw = url?.absoluteString ?? ""
        #expect(raw.hasPrefix("https://x.com/intent/tweet?text="))
        // A bare & would truncate the tweet at "accuracy".
        #expect(!raw.contains("accuracy & counting"))
    }

    @Test func telegramSendsTextEvenWithNoLinkToAttach() {
        let url = LeaderboardShare.telegramURL(text: "standings", url: nil)

        #expect(url?.absoluteString.contains("t.me/share/url") == true)
        #expect(url?.absoluteString.contains("text=standings") == true)
    }
}

struct DiscordSetupReminderTests {

    private let guildId = UUID(uuidString: "6C4F0F14-2B4E-4C0E-9E9F-9A1B2C3D4E5F")!

    private func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "discord.setup.remindedAt.\(guildId.uuidString)")
        defaults.removeObject(forKey: "discord.setup.remindedVersion.\(guildId.uuidString)")
    }

    @Test @MainActor func aNewGuildOwnerIsAskedStraightAway() {
        clear()
        #expect(DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: true, hasChannel: false
        ))
        clear()
    }

    @Test @MainActor func aConnectedGuildIsNeverNagged() {
        clear()
        // Nothing to remind anyone about once a channel exists.
        #expect(!DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: true, hasChannel: true
        ))
        clear()
    }

    @Test @MainActor func onlyTheOwnerIsAsked() {
        clear()
        // An admin cannot be held responsible for the guild's reach, and a
        // member has nothing to act on.
        #expect(!DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: false, hasChannel: false
        ))
        clear()
    }

    @Test @MainActor func sayingNotNowIsRespectedForAMonth() {
        clear()
        let now = Date()
        DiscordSetupReminder.recordShown(guildId: guildId, now: now)

        #expect(!DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: true, hasChannel: false,
            now: now.addingTimeInterval(29 * 24 * 60 * 60)
        ))
        #expect(DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: true, hasChannel: false,
            now: now.addingTimeInterval(DiscordSetupReminder.interval + 1)
        ))
        clear()
    }

    @Test @MainActor func aNewBuildEarnsOneMoreAsk() {
        clear()
        let now = Date()
        DiscordSetupReminder.recordShown(guildId: guildId, now: now)
        // Simulate the app having been updated since the last reminder.
        UserDefaults.standard.set(
            "0.0.0-previous",
            forKey: "discord.setup.remindedVersion.\(guildId.uuidString)"
        )

        #expect(DiscordSetupReminder.shouldRemind(
            guildId: guildId, isOwner: true, hasChannel: false,
            now: now.addingTimeInterval(60)
        ))
        clear()
    }
}
