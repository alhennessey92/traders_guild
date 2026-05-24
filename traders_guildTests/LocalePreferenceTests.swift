//
//  LocalePreferenceTests.swift
//  traders_guildTests
//

import Testing
@testable import traders_guild

struct LocalePreferenceTests {
    @Test func languageCodesNormalizeForApiPayloads() {
        #expect(LocaleOptionCatalog.languageCode(from: " EN_gb ") == "en-gb")
        #expect(LocaleOptionCatalog.languageCode(from: "fr") == "fr")
        #expect(LocaleOptionCatalog.languageCode(from: "Any/all") == LocaleOptionCatalog.allPreferenceCode)
        #expect(LocaleOptionCatalog.languageCode(from: nil).isEmpty)
    }

    @Test func countryCodesNormalizeForApiPayloads() {
        #expect(LocaleOptionCatalog.countryCode(from: " gb ") == "GB")
        #expect(LocaleOptionCatalog.countryCode(from: "us") == "US")
        #expect(LocaleOptionCatalog.countryCode(from: "Worldwide") == LocaleOptionCatalog.allPreferenceCode)
        #expect(LocaleOptionCatalog.countryCode(from: nil).isEmpty)
    }

    @Test func countryDisplayIncludesFriendlyLabelAndFlagWhenPossible() throws {
        let countryLabel = LocaleOptionCatalog.countryLabel(for: "GB")
        let countryDisplay = LocaleOptionCatalog.countryDisplay(for: "gb")
        let flag = try #require(LocaleOptionCatalog.flagEmoji(forCountryCode: "GB"))

        #expect(countryDisplay.contains(countryLabel))
        #expect(flag.unicodeScalars.count == 2)
    }

    @Test func localeMatchScoreWeightsLanguageAboveCountry() {
        #expect(
            LocaleOptionCatalog.matchScore(
                language: "en-gb",
                location: "GB",
                preferredLanguage: "en",
                preferredLocation: "gb"
            ) == 3
        )
        #expect(
            LocaleOptionCatalog.matchScore(
                language: nil,
                location: nil,
                preferredLanguage: "en",
                preferredLocation: "GB"
            ) == 0
        )
        #expect(
            LocaleOptionCatalog.matchScore(
                language: LocaleOptionCatalog.allPreferenceCode,
                location: LocaleOptionCatalog.allPreferenceCode,
                preferredLanguage: "en",
                preferredLocation: "GB"
            ) == 3
        )
    }
}
