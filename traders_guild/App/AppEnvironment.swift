//
//  AppEnvironment.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation

// Optional global app-wide environment
// This class can hold settings or global flags that multiple parts of the app might care about.
class AppEnvironment: ObservableObject {
    // Example flag: dark mode toggle
    @Published var darkModeEnabled: Bool = false
    
    // Could add more global settings here in the future, like:
    // - isTutorialCompleted
    // - appVersion
    // - experimentalFeatureFlags
}
