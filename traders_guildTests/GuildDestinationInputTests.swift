//
//  GuildDestinationInputTests.swift
//  traders_guildTests
//
//  Tests for the paste box that accepts a guild handle or invite code.
//
//  This matters more on iOS than Android: there is no install-referrer
//  equivalent here, so someone who installs from the App Store after seeing a
//  handle — rather than by tapping the link — has only this path. An owner
//  sharing their guild has no control over which form their member ends up
//  holding, so every form has to work.
//

import XCTest
@testable import traders_guild

final class GuildDestinationInputTests: XCTestCase {

    private let slug = GuildDestination.slug("apex-traders")
    private let invite = GuildDestination.invite("ABCD234567")

    func testAcceptsBareHandle() {
        XCTAssertEqual(GuildDestinationInput.parse("apex-traders"), slug)
    }

    func testAcceptsEveryUrlFormOfHandle() {
        XCTAssertEqual(GuildDestinationInput.parse("tradersguild.co/g/apex-traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("https://tradersguild.co/g/apex-traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("http://www.tradersguild.co/g/apex-traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("https://open.tradersguild.co/g/apex-traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("tradersguild://g/apex-traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("/g/apex-traders"), slug)
    }

    func testAcceptsBareInviteCode() {
        XCTAssertEqual(GuildDestinationInput.parse("ABCD234567"), invite)
    }

    func testAcceptsEveryUrlFormOfInviteCode() {
        XCTAssertEqual(GuildDestinationInput.parse("tradersguild.co/invite/ABCD234567"), invite)
        XCTAssertEqual(GuildDestinationInput.parse("https://tradersguild.co/invite/ABCD234567"), invite)
        XCTAssertEqual(GuildDestinationInput.parse("tradersguild://invite?code=ABCD234567"), invite)
        XCTAssertEqual(
            GuildDestinationInput.parse("https://tradersguild.co/invite/ABCD234567?utm_source=x"),
            invite
        )
    }

    func testAcceptsAlternateQueryKeys() {
        XCTAssertEqual(GuildDestinationInput.parse("https://tradersguild.co/?ref=ABCD234567"), invite)
        XCTAssertEqual(GuildDestinationInput.parse("https://tradersguild.co/?invite=ABCD234567"), invite)
        XCTAssertEqual(GuildDestinationInput.parse("https://tradersguild.co/?invite_code=ABCD234567"), invite)
    }

    func testToleratesSloppyPaste() {
        XCTAssertEqual(GuildDestinationInput.parse("  https://tradersguild.co/g/apex-traders/  "), slug)
        XCTAssertEqual(GuildDestinationInput.parse("  apex-traders "), slug)
    }

    func testNormalizesCaseToMatchTheServer() {
        XCTAssertEqual(GuildDestinationInput.parse("Apex-Traders"), slug)
        XCTAssertEqual(GuildDestinationInput.parse("tradersguild.co/invite/abcd234567"), invite)
    }

    /// Codes are exactly 10 characters from an alphabet excluding 0/1/I/O so
    /// they survive being read aloud; slugs are lowercase. That keeps a bare
    /// token unambiguous without having to ask which kind the user has.
    func testBareTokenDisambiguation() {
        XCTAssertEqual(GuildDestinationInput.parse("ABCD234567"), invite)
        XCTAssertEqual(GuildDestinationInput.parse("abcd234567"), .slug("abcd234567"))
        XCTAssertEqual(GuildDestinationInput.parse("abcd12345"), .slug("abcd12345"))
    }

    func testRejectsJunk() {
        XCTAssertNil(GuildDestinationInput.parse(nil))
        XCTAssertNil(GuildDestinationInput.parse(""))
        XCTAssertNil(GuildDestinationInput.parse("   "))
        XCTAssertNil(GuildDestinationInput.parse("https://tradersguild.co/"))
        XCTAssertNil(GuildDestinationInput.parse("hello world"))
        XCTAssertNil(GuildDestinationInput.parse("what is this?"))
    }

    /// A marker link is a real link, but not a guild destination — better to
    /// reject it than to join the user to something they didn't ask for.
    func testRefusesToGuessAtUnrecognisedPaths() {
        XCTAssertNil(GuildDestinationInput.parse("https://tradersguild.co/marker/abc-123"))
        XCTAssertNil(GuildDestinationInput.parse("https://tradersguild.co/features/pricing"))
    }
}
