import Foundation
import Testing
@testable import traders_guild

/// A member who changes their avatar used to keep the old one — or keep showing initials — on
/// every message already on screen, because each message carries its author as a snapshot taken
/// when the message was fetched. Only relaunching the app fixed it.
@MainActor
struct MemberAvatarDirectoryTests {
    private func freshDirectory() -> MemberAvatarDirectory {
        let directory = MemberAvatarDirectory.shared
        directory.clear()
        return directory
    }

    @Test
    func unknownUserFallsBackToWhateverTheMessageCarried() {
        let directory = freshDirectory()
        let userId = UUID()
        #expect(directory.resolved(userId: userId, fallback: "https://x/old.jpg") == "https://x/old.jpg")
        #expect(directory.resolved(userId: nil, fallback: "https://x/old.jpg") == "https://x/old.jpg")
    }

    @Test
    func aFresherAvatarWinsOverTheMessageSnapshot() {
        let directory = freshDirectory()
        let userId = UUID()
        directory.note(userId: userId, avatarURL: "https://x/new.jpg")
        #expect(directory.resolved(userId: userId, fallback: "https://x/old.jpg") == "https://x/new.jpg")
    }

    /// Removing an avatar has to propagate too, or the row keeps drawing a picture the member
    /// has deleted.
    @Test
    func aClearedAvatarBeatsAStaleURL() {
        let directory = freshDirectory()
        let userId = UUID()
        directory.note(userId: userId, avatarURL: nil)
        #expect(directory.resolved(userId: userId, fallback: "https://x/old.jpg") == nil)
    }

    @Test
    func clearingDropsEverythingForTheNextAccount() {
        let directory = freshDirectory()
        let userId = UUID()
        directory.note(userId: userId, avatarURL: "https://x/new.jpg")
        directory.clear()
        #expect(directory.resolved(userId: userId, fallback: "https://x/old.jpg") == "https://x/old.jpg")
    }
}
