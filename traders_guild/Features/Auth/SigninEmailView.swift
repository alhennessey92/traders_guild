//
//  SigninEmail.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//
//
//  SigninEmail.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

import SwiftUI

struct SigninEmailView: View {
    @EnvironmentObject var RLAppState: RLAppState

    @State private var emailOrUsername: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false

    @Environment(\.dismiss) var dismiss

    private var normalizedIdentifier: String {
        RLAuthValidator.trimmed(emailOrUsername)
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidIdentifier(normalizedIdentifier) &&
        !password.isEmpty
    }

    private var identifierHint: String? {
        guard !normalizedIdentifier.isEmpty else { return nil }
        if RLAuthValidator.isValidIdentifier(normalizedIdentifier) {
            return nil
        }
        if RLAuthValidator.isLikelyEmailIdentifier(normalizedIdentifier) {
            return "Enter a valid email address."
        }
        return "Username can contain letters, numbers, dots, underscores, and hyphens."
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Sign In")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    StandardTextFieldView(title: "Email or Username", text: $emailOrUsername)
                        .padding(.bottom, 10)
                        .disabled(isLoggingIn || RLAppState.isLoggingOut)

                    if let identifierHint {
                        Text(identifierHint)
                            .font(AppFonts.smallNotice())
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    StandardTextFieldView(title: "Password", text: $password, isSecure: true)
                        .padding(.bottom, 10)
                        .disabled(isLoggingIn || RLAppState.isLoggingOut)

                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                    .disabled(isLoggingIn)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
            }
            .keyboardPinnedBottomInset(background: AnyView(AuthKeyboardFooterChrome())) {
                VStack(spacing: 0) {
                    Divider()
                        .frame(height: 1)
                        .background(AppColors.surfaceGray30)

                    StandardActionButtonFullWidth(
                        title: isLoggingIn ? "Signing In..." : "Sign In",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task {
                            await handleLogin()
                        }
                    }
                    .disabled(!isFormValid || isLoggingIn || RLAppState.isLoggingOut)
                    .opacity(isFormValid && !isLoggingIn && !RLAppState.isLoggingOut ? 1.0 : 0.5)
                    .overlay {
                        if isLoggingIn {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gradientBackgroundDark))
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.leading, 46)
                        }
                    }

                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot your password?")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    .disabled(isLoggingIn || RLAppState.isLoggingOut)
                }
                .background(Color.clear)
            }
        }
    }

    private func handleLogin() async {
        guard !RLAppState.isLoggingOut else { return }
        isLoggingIn = true

        do {
            try await RLAppState.login(identifier: normalizedIdentifier, password: password)
            try? await Task.sleep(nanoseconds: 100_000_000)
            dismiss()
        } catch {
            isLoggingIn = false
        }
    }
}
