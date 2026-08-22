//
//  ForgotPasswordView.swift
//  traders_guild
//

import SwiftUI

private struct ResetPasswordRequirement: Identifiable {
    let title: String
    let isMet: Bool
    var id: String { title }
}

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

    // MARK: - Password Validation

    private var isValidLength: Bool {
        let bytes = newPassword.utf8.count
        return bytes >= 8 && bytes <= 72
    }

    private var hasUppercase: Bool {
        newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    private var hasLowercase: Bool {
        newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private var hasNumber: Bool {
        newPassword.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private var passwordsMatch: Bool {
        RLAuthValidator.doPasswordsMatch(newPassword, confirmPassword)
    }

    private var passwordRequirements: [ResetPasswordRequirement] {
        [
            ResetPasswordRequirement(title: "8-72 characters", isMet: isValidLength),
            ResetPasswordRequirement(title: "At least one uppercase letter", isMet: hasUppercase),
            ResetPasswordRequirement(title: "At least one lowercase letter", isMet: hasLowercase),
            ResetPasswordRequirement(title: "At least one number", isMet: hasNumber),
        ]
    }

    private var passwordValidationState: StandardTextFieldValidationState {
        if newPassword.isEmpty { return .neutral }
        return RLAuthValidator.isValidPassword(newPassword) ? .valid : .invalid
    }

    private var confirmPasswordValidationState: StandardTextFieldValidationState {
        if confirmPassword.isEmpty { return .neutral }
        return passwordsMatch ? .valid : .invalid
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
                        .padding(.horizontal, 20)

                    if step == .request {
                        requestStepView
                    } else {
                        resetStepView
                    }

                    Spacer(minLength: 160)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
            .platformNavigationBarBackground(AppColors.gradientBackgroundDark)
            .platformNavigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
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
        .keyboardPinnedBottomInset(background: AnyView(AuthKeyboardFooterChrome())) {
            forgotPasswordFooter
        }
        .onAppear {
            if step == .reset, !normalizedToken.isEmpty {
                Task { await verifyTokenIfNeeded() }
            }
        }
    }

    @ViewBuilder
    private var requestStepView: some View {
        Text("Enter your email or username and we will send a secure reset code.")
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
            Text("If the account exists, a reset code has been sent.")
                .font(AppFonts.smallNotice())
                .foregroundColor(AppColors.statusPositive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }

        EmptyView()
    }

    @ViewBuilder
    private var resetStepView: some View {
        Text("Enter your reset code from email, then set a new password.")
            .font(AppFonts.smallNotice())
            .foregroundColor(AppColors.greyText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

        StandardTextFieldView(title: "Reset Code", text: $token)
            .padding(.bottom, 10)
            .disabled(isSubmitting || launchedFromDeepLink)
            .onChange(of: token) { _, _ in
                tokenIsValid = nil
            }

        Text("Password requirements")
            .font(AppFonts.smallNotice())
            .foregroundColor(AppColors.greyText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
            .padding(.bottom, 5)
            .padding(.horizontal, 24)

        StandardTextFieldView(
            title: "New Password",
            text: $newPassword,
            isSecure: true,
            validationState: passwordValidationState
        )
            .padding(.bottom, 10)
            .disabled(isSubmitting)

        VStack(alignment: .leading, spacing: 5) {
            ForEach(passwordRequirements) { requirement in
                HStack(spacing: 7) {
                    Image(systemName: requirement.isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(requirement.isMet ? AppColors.bullCandleGreen : AppColors.bearCandleRed)

                    Text(requirement.title)
                        .font(.caption)
                        .foregroundColor(requirement.isMet ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)

        StandardTextFieldView(
            title: "Confirm Password",
            text: $confirmPassword,
            isSecure: true,
            validationState: confirmPasswordValidationState
        )
            .padding(.bottom, 4)
            .disabled(isSubmitting)

        if !confirmPassword.isEmpty {
            HStack(spacing: 7) {
                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(passwordsMatch ? AppColors.bullCandleGreen : AppColors.bearCandleRed)

                Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                    .font(.caption)
                    .foregroundColor(passwordsMatch ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }

        if let tokenIsValid {
            Text(tokenIsValid ? "Reset code verified." : "Reset code is invalid or expired.")
                .font(AppFonts.smallNotice())
                .foregroundColor(tokenIsValid ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
        }

        EmptyView()
    }

    @ViewBuilder
    private var forgotPasswordFooter: some View {
        VStack(spacing: 10) {
            Divider()
                .frame(height: 1)
                .background(AppColors.surfaceGray30)

            if step == .request {
                StandardActionButtonFullWidth(
                    title: isSubmitting ? "Sending..." : (requestSubmitted ? "Reset Code Sent" : "Send Reset Code"),
                    backgroundColor: requestSubmitted ? AppColors.bullCandleGreen : AppColors.whiteText,
                    foregroundColor: requestSubmitted ? AppColors.whiteText : AppColors.gradientBackgroundDark
                ) {
                    Task { await submitForgotRequest() }
                }
                .disabled(!canRequestReset)
                .opacity(canRequestReset ? 1.0 : 0.5)

                Button {
                    tokenIsValid = nil
                    step = .reset
                } label: {
                    Text("Already have a reset code?")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.accentColor)
                }
            } else {
                StandardActionButtonFullWidth(
                    title: isSubmitting ? "Resetting..." : "Reset Password",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark
                ) {
                    Task { await submitResetPassword() }
                }
                .disabled(!canSubmitReset)
                .opacity(canSubmitReset ? 1.0 : 0.5)

                HStack(spacing: 12) {
                    Button {
                        Task { await verifyTokenIfNeeded() }
                    } label: {
                        Text(isVerifyingToken ? "Verifying..." : "Verify Code")
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
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.clear)
    }

    private func submitForgotRequest() async {
        guard canRequestReset else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await RLAppState.requestPasswordReset(identifier: normalizedIdentifier)
            requestSubmitted = true
        } catch {
            RLAppState.showError(
                title: RLUserFacingCopy.text(.errorTitle),
                message: RLUserFacingCopy.text(.infoPasswordResetRequestFailed),
                style: .toast
            )
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
            RLAppState.showSuccess(RLUserFacingCopy.text(.successPasswordUpdatedSignIn))
            RLAppState.setPendingPasswordResetToken(nil)
            dismiss()
        } catch {
            RLAppState.showError(
                title: RLUserFacingCopy.text(.errorTitle),
                message: RLUserFacingCopy.text(.infoPasswordResetFailed),
                style: .toast
            )
        }
    }
}
