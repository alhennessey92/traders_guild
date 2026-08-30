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
        // Every external destination is named, not summarised as "and others" —
        // the bundled privacy copy names the same list and the two must not drift.
        #expect(disclosure.contains("Reddit"))
        #expect(disclosure.contains("Telegram"))
        #expect(disclosure.contains("profile handle"))
        #expect(disclosure.contains("guild name"))
        #expect(disclosure.contains("public outside Traders Guild"))
        #expect(disclosure.contains("retain or reshare"))
    }

    // MARK: - Headline

    @Test func headlineCombinesTickerIntentAndPrice() {
        let headline = MarkerShare.shareHeadline(
            symbolTicker: "BTC/USD",
            intent: "setup",
            price: 67250.12
        )

        // Leads with the cashtag: on X that is a searchable entity, so the post
        // reaches people following the instrument, not just the author.
        #expect(headline == "$BTC setup at 67,250.12")
    }

    @Test func headlineDropsMissingContextGracefully() {
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTC/USD", intent: nil, price: nil) == "$BTC"
        )
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTC/USD", intent: "alert", price: nil)
                == "$BTC alert"
        )
        #expect(
            MarkerShare.shareHeadline(symbolTicker: nil, intent: "setup", price: 100)
                == "my latest marker"
        )
    }

    @Test func headlineHidesThePersonalIntent() {
        // "BTCUSD personal at ..." reads like a label, not a call.
        #expect(
            MarkerShare.shareHeadline(symbolTicker: "BTC/USD", intent: "personal", price: 100)
                == "$BTC at 100"
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

        // The caption leads and the cashtag rides behind it — the post still has
        // to be findable by instrument.
        #expect(text == "Eyes on this one $BTCUSD \(shareURL.absoluteString)")
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

        // "#BTC" is a hashtag, not this instrument's cashtag, so the tag is still
        // appended — the round-trip being asserted is the escaping, not the copy.
        #expect(message == "\(caption) $BTCUSD \(shareURL.absoluteString)")
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

        #expect(message.contains("**$BTCUSD setup at 67,250.12 on Traders Guild**"))
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

    // MARK: - Share body

    /// Telegram renders the body and *then* unfurls the link separately, so a
    /// URL in the body shows up twice in its composer.
    @Test func theShareBodyCarriesNoLinkOfItsOwn() {
        let generated = MarkerShare.shareBody(
            symbolTicker: "BTC/USD",
            caption: nil,
            intent: "setup",
            price: 67250.12
        )
        let captioned = MarkerShare.shareBody(
            symbolTicker: "BTC/USD",
            caption: "Eyes on this one",
            intent: "setup",
            price: 67250.12
        )

        #expect(!generated.contains("http"))
        #expect(!captioned.contains("http"))
        #expect(generated == "Just marked $BTC setup at 67,250.12 on Traders Guild \u{1F4C8}")
        #expect(captioned == "Eyes on this one $BTC")
    }

    /// Pins the split: the X composer text must stay exactly what it produced
    /// before `shareBody` was extracted out of it.
    @Test func theXComposerTextIsTheBodyPlusTheLink() throws {
        let body = MarkerShare.shareBody(
            symbolTicker: "BTC/USD",
            caption: "Eyes on this one",
            intent: "setup",
            price: 67250.12
        )
        let url = try #require(
            MarkerShare.xComposeURL(
                symbolTicker: "BTC/USD",
                caption: "Eyes on this one",
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )
        let text = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value
        )

        #expect(text == "\(body) \(shareURL.absoluteString)")
    }

    // MARK: - Telegram

    @Test func telegramCarriesTheLinkAndTheBodySeparately() throws {
        let appURL = try #require(
            MarkerShare.telegramAppURL(
                symbolTicker: "BTC/USD",
                caption: nil,
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )
        let webURL = try #require(
            MarkerShare.telegramWebURL(
                symbolTicker: "BTC/USD",
                caption: nil,
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )

        #expect(appURL.scheme == "tg")
        #expect(appURL.host == "msg_url")
        #expect(webURL.absoluteString.hasPrefix("https://t.me/share/url?"))

        for url in [appURL, webURL] {
            let items = try #require(
                URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            )
            let link = try #require(items.first(where: { $0.name == "url" })?.value)
            let text = try #require(items.first(where: { $0.name == "text" })?.value)

            #expect(link == shareURL.absoluteString)
            #expect(!text.contains("http"))
        }
    }

    // MARK: - Reddit

    @Test func redditSubmitsATitleAndAURLToTheDocumentedPage() throws {
        let url = try #require(
            MarkerShare.redditSubmitURL(
                symbolTicker: "BTC/USD",
                caption: nil,
                url: shareURL,
                intent: "setup",
                price: 67250.12
            )
        )
        let items = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        )

        #expect(url.absoluteString.hasPrefix("https://www.reddit.com/submit?"))
        #expect(items.first(where: { $0.name == "url" })?.value == shareURL.absoluteString)
        #expect(
            items.first(where: { $0.name == "title" })?.value
                == MarkerShare.shareBody(
                    symbolTicker: "BTC/USD",
                    caption: nil,
                    intent: "setup",
                    price: 67250.12
                )
        )
    }

    /// A caption can reach 280 characters and the cashtag rides behind it, so
    /// the title has to be cut somewhere — Reddit rejects anything over 300.
    @Test func redditTitleIsClampedToRedditsLimit() {
        let title = MarkerShare.redditTitle(
            symbolTicker: "BTC/USD",
            caption: String(repeating: "x", count: 280),
            intent: "setup",
            price: 67250.12
        )

        #expect(title.count <= MarkerShare.redditTitleLimit)
        #expect(!title.contains("http"))
    }
}


// MARK: - Cashtags

@Suite("Marker cashtags")
struct MarkerCashtagTests {
    @Test func cryptoTagsTheCoinAndForexTagsThePair() {
        // How each is actually searched on X.
        #expect(MarkerShare.cashtag("BTC/USD") == "$BTC")
        #expect(MarkerShare.cashtag("SOL/USD") == "$SOL")
        #expect(MarkerShare.cashtag("EUR/USD") == "$EURUSD")
        #expect(MarkerShare.cashtag("USD/JPY") == "$USDJPY")
        #expect(MarkerShare.cashtag("XAU/USD") == "$XAUUSD")
    }

    @Test func equitiesTagAsTheyTrade() {
        #expect(MarkerShare.cashtag("AAPL") == "$AAPL")
        #expect(MarkerShare.cashtag("NVDA") == "$NVDA")
    }

    @Test func anUnknownPairBaseIsTreatedAsACoin() {
        // The right default for a listing the app has not caught up with.
        #expect(MarkerShare.cashtag("PEPE/USD") == "$PEPE")
    }

    @Test func caseAndStrayDollarAreNormalised() {
        #expect(MarkerShare.cashtag("btc/usd") == "$BTC")
        #expect(MarkerShare.cashtag("$AAPL") == "$AAPL")
    }

    @Test func nothingUsefulYieldsNoTag() {
        #expect(MarkerShare.cashtag(nil) == nil)
        #expect(MarkerShare.cashtag("   ") == nil)
        #expect(MarkerShare.cashtag("weird ticker!") == nil)
    }

    @Test func aCaptionedPostStillCarriesTheCashtag() {
        let text = MarkerShare.xComposeURL(
            symbolTicker: "BTC/USD",
            caption: "Reclaim confirmed",
            url: URL(string: "https://tradersguild.co/marker/abc")!
        )?.absoluteString ?? ""

        #expect(text.contains("%24BTC") || text.contains("$BTC"))
    }

    @Test func aCaptionThatAlreadyTagsIsLeftAlone() {
        let text = MarkerShare.xComposeURL(
            symbolTicker: "BTC/USD",
            caption: "$BTC reclaim confirmed",
            url: URL(string: "https://tradersguild.co/marker/abc")!
        )?.absoluteString ?? ""

        // One tag, not two.
        let encoded = text.replacingOccurrences(of: "%24", with: "$")
        #expect(encoded.components(separatedBy: "$BTC").count - 1 == 1)
    }
}
