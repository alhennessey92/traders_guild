//
//  BiometricEnrollmentView.swift
//  traders_guild
//

import SwiftUI

/// Shown after first successful login to offer FaceID/TouchID enrollment.
/// Presented as a sheet overlay.
struct BiometricEnrollmentView: View {
    @EnvironmentObject var RLAppState: RLAppState
    @Environment(\.dismiss) var dismiss

    @State private var isEnrolling: Bool = false

    private let biometricManager = BiometricAuthManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: biometricManager.biometricIconName)
                .font(.system(size: 64))
                .foregroundColor(AppColors.accentColor)

            Text("Enable \(biometricManager.biometricName)")
                .font(.title2.bold())
                .foregroundColor(AppColors.whiteText)

            Text("Sign in quickly and securely using \(biometricManager.biometricName) next time you open the app.")
                .font(.body)
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    enrollBiometric()
                } label: {
                    LoginButton(
                        title: isEnrolling ? "Setting up..." : "Enable \(biometricManager.biometricName)",
                        iconName: biometricManager.biometricIconName,
                        backgroundColor: AppColors.accentColor,
                        foregroundColor: AppColors.whiteText
                    )
                }
                .disabled(isEnrolling)

                Button {
                    // User declined — persist in Keychain so it survives app reinstall
                    KeychainPreferences.setBool(true, forKey: "traders_guild_biometric_declined")
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.gradientBackgroundDark)
    }

    private func enrollBiometric() {
        isEnrolling = true
        Task {
            do {
                // Authenticate once to confirm the user's biometric
                let authenticated = try await biometricManager.authenticate(
                    reason: "Confirm your identity to enable \(biometricManager.biometricName)"
                )

                guard authenticated else {
                    await MainActor.run { isEnrolling = false }
                    return
                }

                // Store the current refresh token with biometric protection
                if let refreshToken = RLAppState.currentRefreshToken {
                    try biometricManager.storeBiometricRefreshToken(refreshToken)
                    biometricManager.isBiometricEnabled = true

                    await MainActor.run {
                        isEnrolling = false
                        RLAppState.showSuccess("\(biometricManager.biometricName) enabled!")
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isEnrolling = false
                        RLAppState.showError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active session found. Please sign in first."]))
                    }
                }
            } catch {
                await MainActor.run {
                    isEnrolling = false
                    // Don't show error for user cancellation
                    if (error as NSError).code != -2 { // LAError.userCancel
                        RLAppState.showError(error)
                    }
                }
            }
        }
    }
}
