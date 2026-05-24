//
//  GuildCrestDecodingTests.swift
//  traders_guildTests
//
//  Verifies the simplified guild crest fields (crest_symbol / crest_color)
//  decode correctly, legacy guilds without them decode to nil, the crest
//  catalog maps keys safely, and the create-guild request encodes the fields.
//

import Testing
import Foundation
@testable import traders_guild

struct GuildCrestDecodingTests {

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A guild JSON payload; `crestFields` is appended after `updated_at`.
    private func guildPayload(crestFields: String) -> Data {
        Data("""
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Signal Guild",
          "description": null,
          "image_url": null,
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "is_open": true,
          "reputation": 0,
          "member_count": 1,
          "members_online": 0,
          "owner_display_name": null,
          "owner_username": null,
          "owner_avatar_url": null,
          "language": null,
          "location": null,
          "status": "active",
          "date_created": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z"\(crestFields)
        }
        """.utf8)
    }

    @Test func guildDecodesCrestSymbolAndColor() throws {
        let guild = try decoder.decode(
            RLGuildDTO.self,
            from: guildPayload(crestFields: """
            ,
              "crest_symbol": "bolt",
              "crest_color": "blue"
            """)
        )
        #expect(guild.crestSymbol == "bolt")
        #expect(guild.crestColor == "blue")
    }

    @Test func legacyGuildWithoutCrestFieldsDecodesToNil() throws {
        let guild = try decoder.decode(RLGuildDTO.self, from: guildPayload(crestFields: ""))
        #expect(guild.crestSymbol == nil)
        #expect(guild.crestColor == nil)
    }

    @Test func crestCatalogMapsKeysAndFallsBackForUnknown() {
        // nil and unknown keys both fall back to the default checkered shield.
        #expect(GuildCrestCatalog.sfSymbol(for: nil) == "shield.pattern.checkered")
        #expect(GuildCrestCatalog.sfSymbol(for: "checkered") == "shield.pattern.checkered")
        #expect(GuildCrestCatalog.sfSymbol(for: "bolt") == "bolt.shield.fill")
        #expect(GuildCrestCatalog.sfSymbol(for: "totally_unknown") == "shield.pattern.checkered")
        #expect(GuildCrestCatalog.symbolKeys.count == 8)
        #expect(GuildCrestCatalog.colorKeys.contains("brand"))
    }

    @Test func createGuildRequestEncodesCrestFields() throws {
        let request = RLCreateGuildRequestDTO(
            name: "Signal Guild",
            description: nil,
            isOpen: true,
            language: nil,
            location: nil,
            joinQuestions: [],
            initialAnnouncementTitle: "Welcome",
            initialAnnouncementContent: "Hello traders",
            initialAnnouncementPreview: nil,
            initialAnnouncementIsImportant: true,
            crestSymbol: "star_of_life",
            crestColor: "green"
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try #require(String(data: try encoder.encode(request), encoding: .utf8))

        #expect(json.contains("\"crest_symbol\":\"star_of_life\""))
        #expect(json.contains("\"crest_color\":\"green\""))
    }
}
