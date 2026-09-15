import Foundation
import Testing
@testable import traders_guild

/// The RSI / Stochastic level labels once formatted `config?.level ?? 70`
/// straight into `%.0f`; with a nil config that handed Foundation an Int and
/// rendered "0" (and logged a format mismatch on iOS 26). The helper binds a
/// Double first, so the nil case is the one that matters here.
struct IndicatorLevelFormattingTests {
    @Test
    func aMissingConfigFormatsItsFallbackNotZero() {
        let none: RSIConfig? = nil
        #expect(IndicatorLevelFormatting.wholeNumber(none?.overboughtLevel, fallback: 70) == "70")
        #expect(IndicatorLevelFormatting.wholeNumber(none?.oversoldLevel, fallback: 30) == "30")
        let stoch: StochasticConfig? = nil
        #expect(IndicatorLevelFormatting.wholeNumber(stoch?.overboughtLevel, fallback: 80) == "80")
    }

    @Test
    func aPresentConfigFormatsItsOwnLevelRounded() {
        var config = RSIConfig()
        config.overboughtLevel = 72.6
        config.oversoldLevel = 27.4
        let present: RSIConfig? = config
        #expect(IndicatorLevelFormatting.wholeNumber(present?.overboughtLevel, fallback: 70) == "73")
        #expect(IndicatorLevelFormatting.wholeNumber(present?.oversoldLevel, fallback: 30) == "27")
    }
}
