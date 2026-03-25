//
//  ThemeManager.swift
//  traders_guild
//
//  Manages the app-wide theme selection (dark vs mid-grey).
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case dark
    case midGrey

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .midGrey: return "Mid-Grey"
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
