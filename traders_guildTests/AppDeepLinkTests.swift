import Foundation
import Testing
@testable import traders_guild

struct AppDeepLinkTests {
    private let markerId = UUID(uuidString: "6A235097-76B1-43E4-9F4E-2AE9A81608FF")!

    @Test
    func parsesMarkerAcrossCustomAndTrustedWebHosts() {
        let expected = AppDeepLink.marker(markerId)
        let links = [
            "tradersguild://marker/\(markerId.uuidString)",
            "https://tradersguild.co/marker/\(markerId.uuidString)",
            "https://tradersguild.co/marker/\(markerId.uuidString)?share_token=\(String(repeating: "s", count: 43))",
            "https://open.tradersguild.co/marker/\(markerId.uuidString)",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == expected)
        }
    }

    @Test
    func parsesInviteAcrossCustomAndTrustedWebHosts() {
        let links = [
            "tradersguild://invite?code=ABC123",
            "https://tradersguild.co/invite/ABC123",
            "https://open.tradersguild.co/invite/ABC123",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == .referralInvite("ABC123"))
        }
    }

    @Test
    func parsesGuildAcrossCustomAndTrustedWebHosts() {
        let links = [
            "tradersguild://g/macro-traders",
            "https://tradersguild.co/g/macro-traders",
            "https://open.tradersguild.co/g/macro-traders",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == .guildSlug("macro-traders"))
        }
    }

    @Test
    func retainsAuthenticationLinkParsing() {
        #expect(
            AppDeepLink(url: URL(string: "tradersguild://reset-password?token=RESET1")!)
                == .passwordReset("RESET1")
        )
        #expect(
            AppDeepLink(url: URL(string: "https://tradersguild.co/verify-email?token=VERIFY1")!)
                == .emailVerification("VERIFY1")
        )
    }

    @Test
    func rejectsForeignAndInsecureWebLinks() {
        let links = [
            "https://example.com/marker/\(markerId.uuidString)",
            "http://tradersguild.co/marker/\(markerId.uuidString)",
            "https://nottradersguild.co/invite/ABC123",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == nil)
        }
    }

    @Test @MainActor
    func routesColdAndWarmMarkerLinksToTheExactPendingDestination() {
        let destination = DeepLinkDestinationSpy()
        let coldMarkerId = markerId
        let warmMarkerId = UUID(uuidString: "0CFA0D46-5773-42E3-9099-CBB4D3E0519E")!

        #expect(
            AppDeepLinkRouter.route(
                URL(string: "https://open.tradersguild.co/marker/\(coldMarkerId.uuidString)")!,
                to: destination
            )
        )
        #expect(destination.markerId == coldMarkerId)

        #expect(
            AppDeepLinkRouter.route(
                URL(string: "tradersguild://marker/\(warmMarkerId.uuidString)")!,
                to: destination
            )
        )
        #expect(destination.markerId == warmMarkerId)
    }

    @Test @MainActor
    func routesInviteGuildAndAuthenticationDestinations() {
        let destination = DeepLinkDestinationSpy()

        #expect(AppDeepLinkRouter.route(URL(string: "https://tradersguild.co/invite/ABC123")!, to: destination))
        #expect(destination.inviteCode == "ABC123")

        #expect(AppDeepLinkRouter.route(URL(string: "https://open.tradersguild.co/g/macro-traders")!, to: destination))
        #expect(destination.guildSlug == "macro-traders")

        #expect(AppDeepLinkRouter.route(URL(string: "tradersguild://reset-password?token=RESET1")!, to: destination))
        #expect(destination.passwordResetToken == "RESET1")

        #expect(AppDeepLinkRouter.route(URL(string: "tradersguild://verify-email?token=VERIFY1")!, to: destination))
        #expect(destination.emailVerificationToken == "VERIFY1")
    }
}

@MainActor
private final class DeepLinkDestinationSpy: AppDeepLinkDestinationHandling {
    private(set) var inviteCode: String?
    private(set) var guildSlug: String?
    private(set) var markerId: UUID?
    private(set) var passwordResetToken: String?
    private(set) var emailVerificationToken: String?

    func setPendingReferralInviteCode(_ code: String?) { inviteCode = code }
    func setPendingGuildSlug(_ slug: String?) { guildSlug = slug }
    func setPendingMarkerLinkId(_ markerId: UUID) { self.markerId = markerId }
    func setPendingPasswordResetToken(_ token: String?) { passwordResetToken = token }
    func setPendingEmailVerificationToken(_ token: String?) { emailVerificationToken = token }
}
