//
//  ThemeManager.swift
//  traders_guild
//
//  Manages the app-wide theme selection (dark, mid-grey, light-grey).
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case dark
    case midGrey
    case lightGrey

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .midGrey: return "Mid-Grey"
        case .lightGrey: return "Light Grey"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark, .midGrey: return .dark
        case .lightGrey: return .light
        }
    }

    var swatchColor: Color {
        switch self {
        case .dark:      return Color(red: 0x01 / 255.0, green: 0x01 / 255.0, blue: 0x05 / 255.0)
        case .midGrey:   return Color(red: 0x18 / 255.0, green: 0x1C / 255.0, blue: 0x28 / 255.0)
        case .lightGrey: return Color(red: 0xB3 / 255.0, green: 0xBA / 255.0, blue: 0xCC / 255.0)
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("appTheme") var currentTheme: AppTheme = .dark {
        didSet {
            objectWillChange.send()
        }
    }

    private init() {}
}
