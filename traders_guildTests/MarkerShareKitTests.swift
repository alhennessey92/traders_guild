//
//  MarkerShareKitTests.swift
//  traders_guildTests
//
//  Covers the text a shared marker carries into X and Discord, and the
//  decoding of a guild's Discord connection state. The share URL itself is
//  what the backend renders an unfurl card for, so its shape is pinned here.
//

import Testing
import Foundation
@testable import traders_guild

struct MarkerShareKitTests {

    private let markerId = UUID(uuidString: "0B7D0F4A-1C2D-4E5F-8A9B-0C1D2E3F4A5B")!

    private var shareURL: URL {
        URL(
            string: "https://tradersguild.co/marker/\(markerId.uuidString.lowercased())"
                + "?share_token=\(String(repeating: "s", count: 43))"
        )!
    }

    // MARK: - Share URL

    @Test func serverIssuedShareURLIsAcceptedForTheExactMarker() {
        #expect(
            MarkerShare.validatedServerShareURL(
                shareURL.absoluteString,
                markerId: markerId
            ) == shareURL
        )
    }

    #if DEBUG
    @Test func knownStagingOriginIsAcceptedOnlyInDebugBuilds() {
        let stagingURL = shareURL.absoluteString.replacingOccurrences(
            of: "https://tradersguild.co",
            with: "https://api-dev.tradersguild.co"
        )
        #expect(
            MarkerShare.validatedServerShareURL(stagingURL, markerId: markerId) != nil
        )
    }
    #endif

    @Test func bareOrMismatchedMarkerURLsAreRejected() {
        let bare = "https://tradersguild.co/marker/\(markerId.uuidString.lowercased())"
        #expect(MarkerShare.validatedServerShareURL(bare, markerId: markerId) == nil)
        #expect(
            MarkerShare.validatedServerShareURL(
                shareURL.absoluteString,
                markerId: UUID()
            ) == nil
        )
        #expect(
            MarkerShare.validatedServerShareURL(
                shareURL.absoluteString.replacingOccurrences(
                    of: "tradersguild.co",
                    with: "example.com"
                ),
                markerId: markerId
            ) == nil
        )
        #expect(
            MarkerShare.validatedServerShareURL(
                shareURL.absoluteString + "&extra=1",
                markerId: markerId
            ) == nil
        )
    }

    @Test func customSchemeMatchesTheUniversalLink() {
        #expect(
            MarkerShare.markerCustomSchemeURL(markerId: markerId)?.absoluteString
                == "tradersguild://marker/0b7d0f4a-1c2d-4e5f-8a9b-0c1d2e3f4a5b"
        )
    }

    @Test func sharingEligibilitySeparatesGuildForwardingFromPublicConsent() {
        #expect(MarkerShare.canShareWithinGuild(visibility: "guild"))
        #expect(MarkerShare.canShareWithinGuild(visibility: " GUILD "))
        #expect(!MarkerShare.canShareWithinGuild(visibility: "private"))

        #expect(
            MarkerShare.canShareExternally(
                isCurrentUserMarker: true,
                visibility: "guild"
            )
        )
        #expect(
            !MarkerShare.canShareExternally(
                isCurrentUserMarker: false,
                visibility: "guild"
            )
        )
        #expect(
            !MarkerShare.canShareExternally(
                isCurrentUserMarker: true,
                visibility: "private"
            )
        )
    }

    @Test func markerDeepLinkTerminalFailuresHaveActionableCopy() {
        #expect(
            MarkerDeepLinkFailureCopy.terminalFailure(forHTTPStatus: 403)
                == MarkerDeepLinkFailureCopy(
                    title: "Marker Access Required",
                    message: "Join the marker’s guild to view it."
                )
        )
        #expect(
            MarkerDeepLinkFailureCopy.terminalFailure(forHTTPStatus: 404)?.title
                == "Marker Unavailable"
        )
        #expect(MarkerDeepLinkFailureCopy.terminalFailure(forHTTPStatus: 500) == nil)
    }

    @Test func externalSharingDisclosureNamesThePublicBoundary() {
        let disclosure = MarkerShare.externalSharingDisclosure

        #expect(disclosure.contains("X"))
        #expect(disclosure.contains("Discord"))
        #expect(disclosure.contains("profile handle"))
        #expect(disclosure.contains("guild name"))
        #expect(disclosure.contains("public outside Traders Guild"))
        #expect(disclosure.contains("retain or reshare"))
    }

    // MARK: - Headline

    @Test func headlineCombinesTickerIntentAndPrice() {
        let headline = MarkerShare.shareHeadline(
            symbolTicker: "BTCUSD",
            intent: "setup",
            price: 67250.12
        )

        #expect(headline == "BTCUSD setup at 67,250.12")
    }

    @Test func headlineDropsMissingContextGracefully() {
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTCUSD", intent: nil, price: nil) == "BTCUSD"
        )
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTCUSD", intent: "alert", price: nil)
                == "BTCUSD alert"
        )
        #expect(
            MarkerShare.shareHeadline(symbolTicker: nil, intent: "setup", price: 100)
                == "my latest marker"
        )
    }

    @Test func headlineHidesThePersonalIntent() {
        // "BTCUSD personal at ..." reads like a label, not a call.
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTCUSD", intent: "personal", price: 100)
                == "BTCUSD at 100"
        )
    }

    @Test func priceFormattingScalesPrecisionToMagnitude() {
        #expect(MarkerShare.formattedPrice(67250.12) == "67,250.12")
        #expect(MarkerShare.formattedPrice(1.08653) == "1.0865")
        #expect(MarkerShare.formattedPrice(0.00001234) == "0.00001234")
        #expect(MarkerShare.formattedPrice(nil) == nil)
        #expect(MarkerShare.formattedPrice(.nan) == nil)
        #expect(MarkerShare.formattedPrice(.infinity) == nil)
    }

    // MARK: - X composer

    @Test func xComposeTextLeadsWithTheMarkerContext() throws {
        let url = try #require(
            MarkerShare.xComposeURL(
                symbolTicker: "BTCUSD",
                caption: nil,
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )
        let text = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value
        )

        #expect(text.contains("BTCUSD setup at 67,250.12"))
        #expect(text.contains(shareURL.absoluteString))
    }

    @Test func aUserCaptionReplacesTheGeneratedCopy() throws {
        let url = try #require(
            MarkerShare.xComposeURL(
                symbolTicker: "BTCUSD",
                caption: "  Eyes on this one  ",
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )
        let text = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value
        )

        #expect(text == "Eyes on this one \(shareURL.absoluteString)")
    }

    @Test func xAppURLUsesTheNativeComposerScheme() throws {
        let url = try #require(
            MarkerShare.xAppURL(symbolTicker: "BTCUSD", caption: nil, url: shareURL)
        )

        #expect(url.absoluteString.hasPrefix("twitter://post?message="))
    }

    @Test func xAppURLRoundTripsReservedCharactersInTheCaption() throws {
        let caption = "Breakout & retest #BTC?"
        let url = try #require(
            MarkerShare.xAppURL(symbolTicker: "BTCUSD", caption: caption, url: shareURL)
        )
        let message = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "message" })?.value
        )

        #expect(message == "\(caption) \(shareURL.absoluteString)")
    }

    // MARK: - Discord message

    @Test func discordMessageIsMarkdownAndCarriesTheLink() {
        let message = MarkerShare.discordMessage(
            symbolTicker: "BTCUSD",
            caption: nil,
            url: shareURL,
            intent: "setup",
            price: 67250.12
        )

        #expect(message.contains("**BTCUSD setup at 67,250.12 on Traders Guild**"))
        #expect(message.contains(shareURL.absoluteString))
    }

    @Test func discordMessageUsesTheUsersCaptionWhenGiven() {
        let message = MarkerShare.discordMessage(
            symbolTicker: "BTCUSD",
            caption: "Reclaim confirmed",
            url: shareURL
        )

        #expect(message.contains("Reclaim confirmed"))
        #expect(!message.contains("Called it on Traders Guild"))
    }

    // MARK: - Discord channel DTOs

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test func channelListDecodesAndSelectsTheDefaultDestination() throws {
        let json = """
        {
          "channels": [
            {
              "id": "10000000-0000-0000-0000-000000000001",
              "guild_id": "20000000-0000-0000-0000-000000000001",
              "label": "alerts",
              "webhook_masked": "https://discord.com/api/webhooks/111/••••aaaa",
              "webhook_id": "111",
              "is_default": false,
              "auto_post_markers": false,
              "status": "active",
              "consecutive_failures": 0,
              "last_success_at": null,
              "last_failure_reason": null,
              "created_at": "2026-07-01T09:00:00Z"
            },
            {
              "id": "10000000-0000-0000-0000-000000000002",
              "guild_id": "20000000-0000-0000-0000-000000000001",
              "label": "#signals",
              "webhook_masked": "https://discord.com/api/webhooks/222/••••bbbb",
              "webhook_id": "222",
              "is_default": true,
              "auto_post_markers": true,
              "status": "active",
              "consecutive_failures": 0,
              "last_success_at": "2026-07-19T12:00:00Z",
              "last_failure_reason": null,
              "created_at": "2026-07-02T09:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(RLGuildDiscordChannelsListDTO.self, from: json)

        #expect(dto.channels.count == 2)
        #expect(dto.preferredChannel?.webhookId == "222")
        #expect(dto.preferredChannel?.displayLabel == "#signals")
        #expect(dto.preferredChannel?.autoPostMarkers == true)
        // The client must never be handed a usable webhook URL.
        #expect(dto.channels.allSatisfy { $0.webhookMasked?.contains("••••") == true })
    }

    @Test func invalidDefaultFallsBackToTheFirstUsableChannel() throws {
        let json = """
        {
          "channels": [
            {
              "id": "10000000-0000-0000-0000-000000000001",
              "guild_id": "20000000-0000-0000-0000-000000000001",
              "label": "broken",
              "webhook_masked": "masked",
              "webhook_id": "111",
              "is_default": true,
              "auto_post_markers": false,
              "status": "invalid",
              "consecutive_failures": 3,
              "last_success_at": null,
              "last_failure_reason": "Discord rejected this webhook.",
              "created_at": "2026-07-01T09:00:00Z"
            },
            {
              "id": "10000000-0000-0000-0000-000000000002",
              "guild_id": "20000000-0000-0000-0000-000000000001",
              "label": "working",
              "webhook_masked": "masked",
              "webhook_id": "222",
              "is_default": false,
              "auto_post_markers": false,
              "status": "failing",
              "consecutive_failures": 1,
              "last_success_at": null,
              "last_failure_reason": "Temporary failure",
              "created_at": "2026-07-02T09:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(RLGuildDiscordChannelsListDTO.self, from: json)

        #expect(dto.channels[0].needsAttention)
        #expect(!dto.channels[0].canPost)
        #expect(dto.channels[1].needsAttention)
        #expect(dto.channels[1].canPost)
        #expect(dto.preferredChannel?.webhookId == "222")
    }

    @Test func emptyChannelListHasNoPreferredDestination() throws {
        let dto = try decoder.decode(
            RLGuildDiscordChannelsListDTO.self,
            from: Data("{\"channels\":[]}".utf8)
        )
        #expect(dto.channels.isEmpty)
        #expect(dto.preferredChannel == nil)
    }

    @Test func markerDiscordRequestRequiresAChannelId() throws {
        let channelId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(
            RLMarkerDiscordShareRequestDTO(channelId: channelId, caption: "Watch this level")
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["channel_id"] as? String == channelId.uuidString)
        #expect(object["caption"] as? String == "Watch this level")
    }

    @Test func ordinaryDiscordChannelUpdatesOmitTheDeferredAutoPostField() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(
            RLGuildDiscordChannelUpdateRequestDTO(label: "signals")
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["label"] as? String == "signals")
        #expect(object["auto_post_markers"] == nil)
    }

    @Test func apiLoggingRedactsWebhookAndShareBearerSecretsRecursively() throws {
        let secret = "https://discord.com/api/webhooks/123/never-log-this-token"
        let shareURL = "https://tradersguild.co/marker/id?share_token=never-log-this-capability"
        let body = try JSONSerialization.data(withJSONObject: [
            "label": "signals",
            "webhook_url": secret,
            "nested": [
                "refresh_token": "also-secret",
                "share_url": shareURL,
                "count": 2,
            ],
        ])

        let logged = APIRequestLogRedactor.redactedJSONString(from: body)

        #expect(logged.contains("signals"))
        #expect(logged.contains("\"count\":2"))
        #expect(logged.contains("<redacted>"))
        #expect(!logged.contains(secret))
        #expect(!logged.contains("also-secret"))
        #expect(!logged.contains(shareURL))
    }
}
