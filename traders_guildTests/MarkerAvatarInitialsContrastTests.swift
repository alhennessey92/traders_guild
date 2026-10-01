import Testing
@testable import traders_guild

/// Stage 5: the prototype's initials disc must read in every theme.
struct MarkerAvatarInitialsContrastTests {

    @Test
    func thePrototypeInitialsMeetWCAGAAInEveryTheme() {
        // Opaque disc and text, independent of the theme underneath.
        let ratio = MarkerAvatarInitialsStyle.contrastRatio(
            MarkerAvatarInitialsStyle.fillRGB, MarkerAvatarInitialsStyle.textRGB
        )
        #expect(ratio >= 4.5, "WCAG AA for normal text; measured \(ratio)")
        #expect(abs(ratio - 7.47) < 0.05)
    }

    /// The measured Light Grey legacy pairing that prompted the change: disc
    /// #8B8F9A under #676D78 text, as rendered in the theme screenshots.
    @Test
    func theLegacyLightGreyPairingIsWhatFailed() {
        let ratio = MarkerAvatarInitialsStyle.contrastRatio((139, 143, 154), (103, 109, 120))
        #expect(ratio < 3, "measured \(ratio)")
    }
}
