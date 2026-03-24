//
//  ForgotPasswordView.swift
//  traders_guild
//

import SwiftUI

struct ForgotPasswordView: View {
    enum ResetFlowStep {
        case request
        case reset
    }

    @EnvironmentObject var RLAppState: RLAppState
    @Environment(\.dismiss) var dismiss

    @State private var step: ResetFlowStep
    @State private var identifier: String = ""
    @State private var token: String
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var requestSubmitted: Bool = false
    @State private var tokenIsValid: Bool?
    @State private var isSubmitting: Bool = false
    @State private var isVerifyingToken: Bool = false

    private let launchedFromDeepLink: Bool

    init(initialToken: String? = nil, launchedFromDeepLink: Bool = false) {
        let sanitized = RLAuthValidator.trimmed(initialToken ?? "")
        _token = State(initialValue: sanitized)
        _step = State(initialValue: sanitized.isEmpty ? .request : .reset)
        self.launchedFromDeepLink = launchedFromDeepLink
    }

    private var normalizedIdentifier: String {
        RLAuthValidator.trimmed(identifier)
    }

    private var normalizedToken: String {
        RLAuthValidator.trimmed(token)
    }

    private var canRequestReset: Bool {
        RLAuthValidator.isValidIdentifier(normalizedIdentifier) && !isSubmitting && !requestSubmitted
    }

    private var canSubmitReset: Bool {
        !normalizedToken.isEmpty &&
        RLAuthValidator.isValidPassword(newPassword) &&
        RLAuthValidator.doPasswordsMatch(newPassword, confirmPassword) &&
        !isSubmitting &&
        !isVerifyingToken &&
        tokenIsValid != false
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text(step == .request ? "Reset your Password" : "Create a New Password")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    if step == .request {
                        requestStepView
                    } else {
                        resetStepView
                    }

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                    .disabled(isSubmitting || isVerifyingToken)
                }

                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
            }
        }
        .onAppear {
            if step == .reset, !normalizedToken.isEmpty {
                Task { await verifyTokenIfNeeded() }
            }
        }
    }

    @ViewBuilder
    private var requestStepView: some View {
        Text("Enter your email or username and we will send a secure reset link.")
            .font(AppFonts.smallNotice())
            .foregroundColor(AppColors.greyText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

        StandardTextFieldView(title: "Email or Username", text: $identifier)
            .padding(.bottom, 10)
            .disabled(isSubmitting || requestSubmitted)

        if requestSubmitted {
            Text("If the account exists, a reset link has been sent.")
                .font(AppFonts.smallNotice())
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }

        VStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(AppColors.surfaceGray30)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)

        StandardActionButtonFullWidth(
            title: isSubmitting ? "Sending..." : (requestSubmitted ? "Reset Link Sent" : "Send Reset Link"),
            backgroundColor: requestSubmitted ? AppColors.bullCandleGreen : AppColors.whiteText,
            foregroundColor: requestSubmitted ? AppColors.whiteText : AppColors.gradientBackgroundDark
        ) {
            Task { await submitForgotRequest() }
        }
        .frame(maxWidth: .infinity)
        .disabled(!canRequestReset)
        .opacity(canRequestReset ? 1.0 : 0.5)

        Button {
            tokenIsValid = nil
            step = .reset
        } label: {
            Text("Already have a reset token?")
                .font(AppFonts.smallNotice())
                .foregroundColor(AppColors.accentColor)
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var resetStepView: some View {
        Text("Paste your reset token from email, then set a new password.")
            .font(AppFonts.smallNotice())
            .foregroundColor(AppColors.greyText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

        StandardTextFieldView(title: "Reset Token", text: $token)
            .padding(.bottom, 10)
            .disabled(isSubmitting || launchedFromDeepLink)
            .onChange(of: token) { _, _ in
                tokenIsValid = nil
            }

        StandardTextFieldView(title: "New Password", text: $newPassword, isSecure: true)
            .padding(.bottom, 10)
            .disabled(isSubmitting)

        StandardTextFieldView(title: "Confirm Password", text: $confirmPassword, isSecure: true)
            .padding(.bottom, 10)
            .disabled(isSubmitting)

        Text("Password must be 8-72 characters with uppercase, lowercase, and a number.")
            .font(AppFonts.smallNotice())
            .foregroundColor(AppColors.greyText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)

        if let tokenIsValid {
            Text(tokenIsValid ? "Reset token verified." : "Reset token is invalid or expired.")
                .font(AppFonts.smallNotice())
                .foregroundColor(tokenIsValid ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
        }

        VStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(AppColors.surfaceGray30)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)

        StandardActionButtonFullWidth(
            title: isSubmitting ? "Resetting..." : "Reset Password",
            backgroundColor: AppColors.whiteText,
            foregroundColor: AppColors.gradientBackgroundDark
        ) {
            Task { await submitResetPassword() }
        }
        .frame(maxWidth: .infinity)
        .disabled(!canSubmitReset)
        .opacity(canSubmitReset ? 1.0 : 0.5)

        HStack(spacing: 12) {
            Button {
                Task { await verifyTokenIfNeeded() }
            } label: {
                Text(isVerifyingToken ? "Verifying..." : "Verify Token")
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.accentColor)
            }
            .disabled(normalizedToken.isEmpty || isSubmitting || isVerifyingToken)

            if !launchedFromDeepLink {
                Button {
                    step = .request
                } label: {
                    Text("Back to Email Step")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                }
                .disabled(isSubmitting || isVerifyingToken)
            }
        }
        .padding(.top, 10)
    }

    private func submitForgotRequest() async {
        guard canRequestReset else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await RLAppState.requestPasswordReset(identifier: normalizedIdentifier)
            requestSubmitted = true
        } catch {
            return
        }
    }

    private func verifyTokenIfNeeded() async {
        guard !normalizedToken.isEmpty else { return }
        isVerifyingToken = true
        defer { isVerifyingToken = false }

        do {
            let response = try await RLAppState.verifyPasswordResetToken(normalizedToken)
            tokenIsValid = response.valid
        } catch {
            tokenIsValid = false
        }
    }

    private func submitResetPassword() async {
        guard canSubmitReset else { return }

        if tokenIsValid == nil {
            await verifyTokenIfNeeded()
        }
        guard tokenIsValid != false else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await RLAppState.resetPassword(token: normalizedToken, newPassword: newPassword)
            RLAppState.showSuccess("Password updated. Please sign in with your new password.")
            RLAppState.setPendingPasswordResetToken(nil)
            dismiss()
        } catch {
            return
        }
    }
}
