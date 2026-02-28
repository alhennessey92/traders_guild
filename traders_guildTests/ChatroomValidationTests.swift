import Foundation
import Testing
@testable import traders_guild

struct ChatroomValidationTests {
    @Test func iconValidationAcceptsSinglePrintableASCII() async throws {
        #expect(ChatroomValidation.isValidIcon("A"))
        #expect(ChatroomValidation.isValidIcon("@"))
        #expect(ChatroomValidation.isValidIcon("#"))
    }

    @Test func iconValidationRejectsInvalidIcons() async throws {
        #expect(!ChatroomValidation.isValidIcon(""))
        #expect(!ChatroomValidation.isValidIcon("AB"))
        #expect(!ChatroomValidation.isValidIcon(" "))
        #expect(!ChatroomValidation.isValidIcon("💡"))
    }

    @Test func descriptionValidationRejectsBlankValues() async throws {
        #expect(!ChatroomValidation.isValidDescription(""))
        #expect(!ChatroomValidation.isValidDescription("   "))
        #expect(ChatroomValidation.isValidDescription("General discussion"))
    }

    @Test func chatroomDTOIconDefaultsToHashWhenAbsent() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "guild_id": "\(UUID().uuidString)",
          "name": "general",
          "description": "General chat",
          "is_active": true,
          "last_activity": "2026-02-27T12:00:00Z",
          "last_activity_formatted": "Just now",
          "unread_count": 0,
          "member_count": 42,
          "is_pinned": false,
          "is_muted": false,
          "can_send_messages": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLGuildChatroomDTO.self, from: data)
        #expect(dto.icon == "#")
        #expect(dto.displayIcon == "#")
    }
}
