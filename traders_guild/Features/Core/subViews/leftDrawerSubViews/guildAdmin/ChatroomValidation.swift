//
//  ChatroomValidation.swift
//  traders_guild
//
//  Shared validation rules for admin chatroom create/edit forms.
//

import Foundation

enum ChatroomValidation {
    private static let iconDefault = "#"

    static func isValidName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidDescription(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidIcon(_ value: String) -> Bool {
        normalizedIcon(value) != nil
    }

    static func fallbackIcon(for value: String?) -> String {
        normalizedIcon(value ?? "") ?? iconDefault
    }

    static func normalizedIcon(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else { return nil }
        guard scalar.value >= 33 && scalar.value <= 126 else { return nil }
        return String(trimmed)
    }

    static func sanitizedIconInput(_ rawValue: String) -> String {
        guard let firstValidChar = rawValue.first(where: { char in
            guard let scalar = char.unicodeScalars.first else { return false }
            return scalar.value >= 33 && scalar.value <= 126
        }) else {
            return ""
        }
        return String(firstValidChar)
    }
}
