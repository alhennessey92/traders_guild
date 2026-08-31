//
//  ShareChannelOrderTests.swift
//  traders_guildTests
//
//  The share surfaces must offer their channels in one order.
//
//  They drifted once already: the marker sheet and the invite hub each declared a private
//  `ChannelKind` and their own literal ordering, so X and Discord sat in opposite positions
//  and Telegram and Reddit were swapped. Someone who had shared a guild invite could not
//  find X where they expected it when sharing a marker.
//
//  `ShareChannelStyle` had been introduced to stop these two drifting, but it only owned
//  how a channel *looks*. These tests pin the other half.
//

import XCTest
@testable import traders_guild

final class ShareChannelOrderTests: XCTestCase {

    func testCanonicalOrderCoversEveryChannelExactlyOnce() {
        XCTAssertEqual(
            Set(ShareChannel.canonicalOrder),
            Set(ShareChannel.allCases),
            "a channel missing from canonicalOrder has no defined position"
        )
        XCTAssertEqual(
            ShareChannel.canonicalOrder.count,
            ShareChannel.allCases.count,
            "canonicalOrder must not list a channel twice"
        )
    }

    /// Both surfaces lay out four to a row, so the first four entries are the top row.
    func testTheTopRowIsAlwaysTheFourPublicChannels() {
        XCTAssertEqual(
            Array(ShareChannel.canonicalOrder.prefix(4)),
            [.x, .discord, .reddit, .telegram],
            "the top row of every share screen is X, Discord, Reddit, Telegram"
        )
    }

    func testEverythingElseSitsUnderneath() {
        let order = ShareChannel.canonicalOrder
        func index(_ channel: ShareChannel) -> Int { order.firstIndex(of: channel)! }

        for social in [ShareChannel.x, .discord, .reddit, .telegram] {
            for other in [ShareChannel.guildDM, .messages, .copyLink, .qrCode, .more] {
                XCTAssertLessThan(
                    index(social),
                    index(other),
                    "\(social) must sit above \(other)"
                )
            }
        }
        // Among the rest: the direct channel first, More last.
        XCTAssertLessThan(index(.guildDM), index(.copyLink))
        XCTAssertLessThan(index(.messages), index(.copyLink))
        XCTAssertLessThan(index(.copyLink), index(.qrCode))
        XCTAssertLessThan(index(.qrCode), index(.more))
    }

    /// Each surface may omit channels, but never reorder them.
    private func assertIsSubsequenceOfCanonical(
        _ channels: [ShareChannel],
        _ surface: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let positions = channels.map { ShareChannel.canonicalOrder.firstIndex(of: $0)! }
        XCTAssertEqual(
            positions,
            positions.sorted(),
            "\(surface) offers its channels out of canonical order",
            file: file,
            line: line
        )
        XCTAssertEqual(
            Set(channels).count,
            channels.count,
            "\(surface) lists a channel twice",
            file: file,
            line: line
        )
    }

    func testMarkerSheetFollowsCanonicalOrder() {
        assertIsSubsequenceOfCanonical(
            [.x, .discord, .reddit, .telegram, .guildDM, .copyLink, .more],
            "the marker share sheet"
        )
    }

    func testInviteHubFollowsCanonicalOrder() {
        assertIsSubsequenceOfCanonical(
            [.x, .discord, .reddit, .telegram, .messages, .copyLink, .qrCode, .more],
            "the guild invite hub"
        )
    }
}
