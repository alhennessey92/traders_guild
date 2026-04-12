import Foundation

struct LocaleOption: Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }
}

enum LocaleOptionCatalog {
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
        return languages.contains(where: { $0.code == code }) ? code : ""
    }

    static func defaultCountryCode() -> String {
        let code = Locale.current.region?.identifier ?? ""
        return countries.contains(where: { $0.code == code }) ? code : ""
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
}
