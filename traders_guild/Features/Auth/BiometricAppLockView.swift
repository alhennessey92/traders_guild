import SwiftUI

struct BiometricAppLockView: View {
    @EnvironmentObject private var rlAppState: RLAppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastHandledUnlockRequestID: UUID?

    private let biometricManager = BiometricAuthManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 22) {
                    VStack(spacing: 14) {
                        Image(systemName: biometricManager.biometricIconName)
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundColor(AppColors.whiteText)

                        Text("Unlock Traders Guild")
                            .font(AppFonts.title(size: 34))
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)

                        Text("Use \(biometricManager.biometricName) to access your session.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                    }

                    if let errorMessage = rlAppState.biometricUnlockErrorMessage,
                       !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.statusWarning95)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    Button {
                        Task {
                            await rlAppState.unlockBiometricAppLock()
                        }
                    } label: {
                        LoginButton(
                            title: rlAppState.isBiometricUnlockInProgress
                                ? "Unlocking..."
                                : "Unlock with \(biometricManager.biometricName)",
                            iconName: biometricManager.biometricIconName,
                            backgroundColor: AppColors.accentColor,
                            foregroundColor: AppColors.whiteText
                        )
                    }
                    .disabled(rlAppState.isBiometricUnlockInProgress)

                    Button("Log Out") {
                        rlAppState.logout()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.surfaceWhite84)
                    .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 420)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppColors.gradientBackgroundDark.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.34), radius: 30, x: 0, y: 18)
                .padding(24)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.16).ignoresSafeArea())
        .onAppear {
            attemptAutomaticUnlockIfNeeded()
        }
        .onChange(of: scenePhase) { _, _ in
            attemptAutomaticUnlockIfNeeded()
        }
        .onChange(of: rlAppState.biometricUnlockRequestID) { _, _ in
            attemptAutomaticUnlockIfNeeded()
        }
    }

    private func attemptAutomaticUnlockIfNeeded() {
        guard scenePhase == .active,
              rlAppState.shouldPresentBiometricAppLock,
              let requestID = rlAppState.biometricUnlockRequestID,
              requestID != lastHandledUnlockRequestID else {
            return
        }

        lastHandledUnlockRequestID = requestID
        Task {
            await rlAppState.unlockBiometricAppLock()
        }
    }
}
