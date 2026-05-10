//
//  ReviewPromptManager.swift
//  traders_guild
//
//  Manages App Store review prompts triggered by positive in-app moments.
//
//  Apple's `SKStoreReviewController` enforces a hard limit of 3 prompts per
//  365-day window per user. We layer additional gating on top so the first
//  prompt only fires after the user has placed `firstPromptMarkerThreshold`
//  markers — i.e., they've engaged with the core feature, not just opened
//  the app. Subsequent prompts are gated by a minimum-days cooldown.
//
//  Wire-up: call `ReviewPromptManager.shared.start()` once from the app
//  entry point. The manager observes `.markerCreatedSuccessfully` and
//  handles the rest.
//

import Foundation
import StoreKit
import UIKit

final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    // MARK: - Tunables

    /// Number of markers the user must place before the first prompt fires.
    /// Three is enough to demonstrate genuine engagement without being annoying.
    private let firstPromptMarkerThreshold = 3

    /// Minimum days between prompts. Apple caps at 3 prompts / 365 days,
    /// so a 90-day floor keeps us well inside that envelope.
    private let minDaysBetweenPrompts = 90

    /// Slight delay so the in-app success UI (toast, confetti, etc.) lands
    /// before the system sheet appears.
    private let postSuccessDelaySeconds: TimeInterval = 1.5

    // MARK: - Persistence keys

    private let markersPlacedKey = "rpm.markersPlacedCount"
    private let lastPromptDateKey = "rpm.lastPromptDate"

    // MARK: - State

    private var observer: NSObjectProtocol?

    private init() {}

    /// Begin observing marker-creation success.
    /// Safe to call multiple times; only the first call attaches the observer.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .markerCreatedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMarkerCreated()
        }
    }

    // MARK: - Core flow

    private func handleMarkerCreated() {
        let defaults = UserDefaults.standard
        let newCount = defaults.integer(forKey: markersPlacedKey) + 1
        defaults.set(newCount, forKey: markersPlacedKey)

        guard newCount >= firstPromptMarkerThreshold else { return }
        guard shouldPromptNow() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + postSuccessDelaySeconds) { [weak self] in
            Task { @MainActor in
                self?.requestReview()
            }
        }
    }

    private func shouldPromptNow() -> Bool {
        let defaults = UserDefaults.standard
        guard let lastPrompt = defaults.object(forKey: lastPromptDateKey) as? Date else {
            return true
        }
        let daysSince = Calendar.current.dateComponents(
            [.day],
            from: lastPrompt,
            to: Date()
        ).day ?? 0
        return daysSince >= minDaysBetweenPrompts
    }

    @MainActor
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        AppStore.requestReview(in: scene)
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
    }
}
