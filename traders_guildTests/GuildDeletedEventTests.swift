import Foundation
import Testing
@testable import traders_guild

/// The wire contract for `guild_deleted`.
///
/// The event is what tells a member sitting in a guild that its owner has just
/// closed it. Miss it and they stay on a shell whose every request 404s until
/// the next cold start — so the type has to be recognised and the payload has
/// to decode, including when the server sends no relocations at all.
struct GuildDeletedEventTests {

    @Test func theEventTypeIsRecognised() {
        #expect(WSMessageType(rawValue: "guild_deleted") == .guildDeleted)
        // Neighbouring guild events must keep their own identity.
        #expect(WSMessageType(rawValue: "guild_updated") == .guildUpdated)
    }

    @Test func payloadDecodesTheGuildId() throws {
        let guildId = UUID().uuidString
        let json = #"{"guild_id": "\#(guildId)"}"#.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(WSGuildDeletedPayload.self, from: json)

        #expect(payload.guildId == guildId)
    }

    /// The event must still decode if the server ever adds fields — a client
    /// that throws here would never leave the deleted guild.
    @Test func payloadIgnoresUnknownFields() throws {
        let guildId = UUID().uuidString
        let json = """
        {"guild_id": "\(guildId)", "something_new": {"a": "b"}}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(WSGuildDeletedPayload.self, from: json)

        #expect(payload.guildId == guildId)
    }
}
