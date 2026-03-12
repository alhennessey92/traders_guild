import Foundation

struct LocaleOption: Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }
}

enum LocaleOptionCatalog {
    static let languages: [LocaleOption] = {
        let locale = Locale.current
        return Locale.isoLanguageCodes
            .compactMap { code in
                guard let label = locale.localizedString(forLanguageCode: code) else { return nil }
                let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return LocaleOption(code: code, label: trimmed.capitalized)
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }()

    static let countries: [LocaleOption] = {
        let locale = Locale.current
        return Locale.isoRegionCodes
            .compactMap { code in
                guard let label = locale.localizedString(forRegionCode: code) else { return nil }
                let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return LocaleOption(code: code, label: trimmed)
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }()

    static func defaultLanguageCode() -> String {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let locale = Locale(identifier: preferred)
        let code = locale.languageCode ?? preferred.components(separatedBy: "-").first ?? ""
        return languages.contains(where: { $0.code == code }) ? code : ""
    }

    static func defaultCountryCode() -> String {
        let code = Locale.current.regionCode ?? ""
        return countries.contains(where: { $0.code == code }) ? code : ""
    }
}
