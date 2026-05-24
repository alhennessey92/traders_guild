import Foundation

struct LocaleOption: Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }
}

enum LocaleOptionCatalog {
    static let allPreferenceCode = "all"
    static let fallbackLanguageCode = "en"
    static let fallbackCountryCode = "US"

    private static let allLanguageLabels = Set([
        "all", "any", "any/all", "all languages", "any language", "any languages"
    ])
    private static let allCountryLabels = Set([
        "all", "any", "any/all", "all countries", "all locations",
        "any country", "any countries", "any location", "any locations",
        "global", "worldwide"
    ])

    private static let commonLanguageCodes: [String] = [
        "en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko", "ar", "hi", "ru"
    ]

    private static let commonCountryCodes: [String] = [
        "US", "GB", "CA", "AU", "DE", "FR", "ES", "IT", "NL", "SE",
        "NO", "DK", "IE", "NZ", "SG", "AE", "IN", "JP", "KR", "BR", "MX"
    ]

    static let languages: [LocaleOption] = {
        let locale = Locale.current
        let options = Locale.LanguageCode.isoLanguageCodes
            .compactMap { code -> LocaleOption? in
                let codeValue = code.identifier
                guard let label = locale.localizedString(forLanguageCode: codeValue) else { return nil }
                let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return LocaleOption(code: codeValue, label: trimmed.capitalized)
            }
        return orderedOptions(options, commonCodes: commonLanguageCodes)
    }()

    static let countries: [LocaleOption] = {
        let locale = Locale.current
        let options = Locale.Region.isoRegions
            .compactMap { code -> LocaleOption? in
                let codeValue = code.identifier
                guard let label = locale.localizedString(forRegionCode: codeValue) else { return nil }
                let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return LocaleOption(code: codeValue, label: trimmed)
            }
        return orderedOptions(options, commonCodes: commonCountryCodes)
    }()

    static func defaultLanguageCode() -> String {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let locale = Locale(identifier: preferred)
        let code = locale.language.languageCode?.identifier ?? preferred.components(separatedBy: "-").first ?? ""
        return languageCode(from: code)
    }

    static func defaultCountryCode() -> String {
        let code = Locale.current.region?.identifier ?? ""
        return countryCode(from: code)
    }

    static func languageCode(from value: String?) -> String {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        if allLanguageLabels.contains(normalized.lowercased()) {
            return allPreferenceCode
        }
        if let option = languages.first(where: { $0.code.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return option.code
        }
        if let option = languages.first(where: { $0.label.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return option.code
        }
        if isLanguageCodeLike(normalized) {
            return normalized.replacingOccurrences(of: "_", with: "-").lowercased()
        }
        return normalized
    }

    static func countryCode(from value: String?) -> String {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        if allCountryLabels.contains(normalized.lowercased()) {
            return allPreferenceCode
        }
        if let option = countries.first(where: { $0.code.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return option.code
        }
        if let option = countries.first(where: { $0.label.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return option.code
        }
        if normalized.count == 2, normalized.allSatisfy(\.isLetter) {
            return normalized.uppercased()
        }
        return normalized
    }

    static func languageLabel(for code: String?) -> String {
        let normalized = languageCode(from: code)
        guard !normalized.isEmpty else { return "Not specified" }
        if normalized == allPreferenceCode {
            return "All languages"
        }
        return languages.first(where: { $0.code.caseInsensitiveCompare(normalized) == .orderedSame })?.label ?? normalized
    }

    static func countryLabel(for code: String?) -> String {
        let normalized = countryCode(from: code)
        guard !normalized.isEmpty else { return "Not specified" }
        if normalized == allPreferenceCode {
            return "All locations"
        }
        return countries.first(where: { $0.code.caseInsensitiveCompare(normalized) == .orderedSame })?.label ?? normalized
    }

    static func countryDisplay(for code: String?) -> String {
        let normalized = countryCode(from: code)
        guard !normalized.isEmpty else { return "Not specified" }
        let label = countryLabel(for: normalized)
        if let flag = flagEmoji(forCountryCode: normalized) {
            return "\(flag) \(label)"
        }
        return label
    }

    static func flagEmoji(forCountryCode code: String?) -> String? {
        let normalized = countryCode(from: code)
        guard normalized.count == 2, normalized.allSatisfy(\.isLetter) else { return nil }
        let base: UInt32 = 127397
        let scalars = normalized.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    static func languageMatches(_ language: String?, preferred: String?) -> Bool {
        let normalizedLanguage = languageCode(from: language)
        let preferredCode = languageCode(from: preferred)
        guard !normalizedLanguage.isEmpty, !preferredCode.isEmpty else { return false }
        if normalizedLanguage == allPreferenceCode || preferredCode == allPreferenceCode {
            return true
        }
        if normalizedLanguage.caseInsensitiveCompare(preferredCode) == .orderedSame {
            return true
        }
        return normalizedLanguage.split(separator: "-").first?.lowercased() == preferredCode.split(separator: "-").first?.lowercased()
    }

    static func countryMatches(_ country: String?, preferred: String?) -> Bool {
        let normalizedCountry = countryCode(from: country)
        let preferredCode = countryCode(from: preferred)
        guard !normalizedCountry.isEmpty, !preferredCode.isEmpty else { return false }
        if normalizedCountry == allPreferenceCode || preferredCode == allPreferenceCode {
            return true
        }
        return normalizedCountry.caseInsensitiveCompare(preferredCode) == .orderedSame
    }

    static func matchScore(
        language: String?,
        location: String?,
        preferredLanguage: String?,
        preferredLocation: String?
    ) -> Int {
        var score = 0
        if languageMatches(language, preferred: preferredLanguage) {
            score += 2
        }
        if countryMatches(location, preferred: preferredLocation) {
            score += 1
        }
        return score
    }

    private static func orderedOptions(_ options: [LocaleOption], commonCodes: [String]) -> [LocaleOption] {
        let sortedOptions = options.sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }

        let optionsByCode = Dictionary(uniqueKeysWithValues: sortedOptions.map { ($0.code, $0) })
        var ordered: [LocaleOption] = []
        var seenCodes = Set<String>()

        for code in commonCodes {
            guard let option = optionsByCode[code], seenCodes.insert(code).inserted else { continue }
            ordered.append(option)
        }

        for option in sortedOptions where seenCodes.insert(option.code).inserted {
            ordered.append(option)
        }

        return ordered
    }

    private static func isLanguageCodeLike(_ value: String) -> Bool {
        guard value.count <= 12 else { return false }
        let parts = value.replacingOccurrences(of: "_", with: "-").split(separator: "-")
        return !parts.isEmpty && parts.allSatisfy { part in
            part.allSatisfy { $0.isLetter || $0.isNumber }
        }
    }
}
