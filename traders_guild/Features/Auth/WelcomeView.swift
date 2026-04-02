//
//  WelcomeView.swift
//  traders_guild
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Binding var path: [RLSignupStep]
    @Binding var data: RLSignupData
    @EnvironmentObject var RLAppState: RLAppState

    @State private var opacity: Double = 0
    @State private var isAppleSignInLoading = false
    @State private var isBiometricLoading = false
    @State private var hasAttemptedAutoBiometricLogin = false
    private let appleSignInCoordinator = AppleSignInCoordinator()
    private let biometricManager = BiometricAuthManager.shared

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    Text("Traders")
                        .font(AppFonts.title(size: 66))
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 50)
                        .padding(.leading, 20)

                    Text("Guild")
                        .font(AppFonts.title(size: 66))
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 40)
                        .padding(.leading, 20)
                }

                Spacer()

                VStack(spacing: 10) {
                    // Biometric login button (only if enabled and available)
                    if biometricManager.canUseBiometricLogin {
                        Button {
                            handleBiometricLogin()
                        } label: {
                            LoginButton(
                                title: isBiometricLoading ? "Signing in..." : "Sign in with \(biometricManager.biometricName)",
                                iconName: biometricManager.biometricIconName,
                                backgroundColor: AppColors.accentColor,
                                foregroundColor: AppColors.whiteText
                            )
                        }
                        .disabled(isBiometricLoading)
                    }

                    Button {
                        handleAppleSignIn()
                    } label: {
                        LoginButton(
                            title: isAppleSignInLoading ? "Signing in..." : "Sign in with Apple",
                            iconName: "apple.logo",
                            backgroundColor: AppColors.whiteText.opacity(0.8),
                            foregroundColor: AppColors.gradientBackgroundDark
                        )
                    }
                    .disabled(isAppleSignInLoading)

                    HStack(alignment: .center) {
                        Rectangle()
                            .fill(AppColors.surfaceGray50)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)

                        Text("OR")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 8)

                        Rectangle()
                            .fill(AppColors.surfaceGray50)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical)

                    NavigationLink(destination: SigninEmailView()) {
                        LoginButton(
                            title: "Sign in with Email",
                            iconName: "envelope.fill",
                            backgroundColor: AppColors.whiteText.opacity(0.8),
                            foregroundColor: AppColors.gradientBackgroundDark
                        )
                    }

                    Button {
                        RLAppState.showInfo("Google sign-in will be enabled in an upcoming release.")
                    } label: {
                        LoginButton(
                            title: "Sign in with Google",
                            iconName: "g.circle.fill",
                            backgroundColor: AppColors.whiteText.opacity(0.8),
                            foregroundColor: AppColors.gradientBackgroundDark
                        )
                    }
                }

                Divider()

                Text("By signing in, you agree to our Terms Of Use, Privacy Policy and Cookies Policy")
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(spacing: 10) {
                    Divider()
                        .frame(height: 1)
                        .background(AppColors.surfaceGray50)

                    HStack {
                        Text("Don't have an account?")

                        Text("Sign up Here")
                            .bold()
                            .foregroundColor(AppColors.accentColor)
                            .onTapGesture {
                                path.append(.accountInfo)
                            }
                    }
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                }
            }
            .padding()
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
        .task(id: RLAppState.isSessionRestored) {
            guard RLAppState.isSessionRestored,
                  !RLAppState.isAuthenticated,
                  !hasAttemptedAutoBiometricLogin,
                  biometricManager.canUseBiometricLogin else {
                return
            }

            hasAttemptedAutoBiometricLogin = true
            handleBiometricLogin(autoTriggered: true)
        }
    }

    private func handleBiometricLogin(autoTriggered: Bool = false) {
        guard !isBiometricLoading else { return }
        isBiometricLoading = true
        Task {
            do {
                try await RLAppState.loginWithBiometric()
                await MainActor.run { isBiometricLoading = false }
            } catch {
                await MainActor.run {
                    isBiometricLoading = false
                    // Don't show error for user cancellation
                    if case BiometricAuthManager.BiometricError.authenticationFailed = error {
                        // User cancelled — silent
                    } else if autoTriggered {
                        // Automatic launch prompts should quietly fall back to manual auth.
                    } else {
                        RLAppState.showError(error)
                    }
                }
            }
        }
    }

    private func handleAppleSignIn() {
        isAppleSignInLoading = true
        Task {
            do {
                let result = try await appleSignInCoordinator.signIn()
                let fullName = [result.fullName?.givenName, result.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                try await RLAppState.loginWithApple(
                    identityToken: result.identityToken,
                    authorizationCode: result.authorizationCode,
                    fullName: fullName.isEmpty ? nil : fullName,
                    email: result.email
                )
                await MainActor.run {
                    isAppleSignInLoading = false
                }
            } catch let error as AppleSignInCoordinator.AppleSignInError where error == .cancelled {
                await MainActor.run { isAppleSignInLoading = false }
            } catch {
                await MainActor.run {
                    isAppleSignInLoading = false
                    RLAppState.showError(error)
                }
            }
        }
    }
}
