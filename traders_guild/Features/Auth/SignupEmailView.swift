//
//  SignupEmailView.swift
//  traders_guild
//

import SwiftUI

private struct SignupPasswordRequirement: Identifiable {
    let title: String
    let isMet: Bool

    var id: String { title }
}

struct SignupEmailView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var emailAvailabilityError: String?
    @State private var isCheckingAvailability: Bool = false

    private var normalizedName: String {
        RLAuthValidator.trimmed(name)
    }

    private var normalizedEmail: String {
        RLAuthValidator.trimmed(email).lowercased()
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidDisplayName(normalizedName) &&
        RLAuthValidator.isValidEmail(normalizedEmail) &&
        RLAuthValidator.isValidPassword(password) &&
        RLAuthValidator.doPasswordsMatch(password, confirmPassword)
    }

    private var isValidLength: Bool {
        let bytes = password.utf8.count
        return bytes >= 8 && bytes <= 72
    }

    private var hasUppercase: Bool {
        password.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    private var hasLowercase: Bool {
        password.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private var hasNumber: Bool {
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private var passwordsMatch: Bool {
        RLAuthValidator.doPasswordsMatch(password, confirmPassword)
    }

    private var passwordRequirements: [SignupPasswordRequirement] {
        [
            SignupPasswordRequirement(title: "8-72 characters", isMet: isValidLength),
            SignupPasswordRequirement(title: "At least one uppercase letter", isMet: hasUppercase),
            SignupPasswordRequirement(title: "At least one lowercase letter", isMet: hasLowercase),
            SignupPasswordRequirement(title: "At least one number", isMet: hasNumber),
        ]
    }

    private var passwordValidationState: StandardTextFieldValidationState {
        if password.isEmpty { return .neutral }
        return RLAuthValidator.isValidPassword(password) ? .valid : .invalid
    }

    private var confirmPasswordValidationState: StandardTextFieldValidationState {
        if confirmPassword.isEmpty { return .neutral }
        return passwordsMatch ? .valid : .invalid
    }

    private var passwordMatchColor: Color {
        passwordsMatch ? AppColors.bullCandleGreen : AppColors.bearCandleRed
    }

    private var emailValidationState: StandardTextFieldValidationState {
        emailAvailabilityError == nil ? .neutral : .invalid
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Step 1 of 5")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    HStack(spacing: 6) {
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                    }
                    .padding(.horizontal, 20)

                    Text("Create your account")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    StandardTextFieldView(title: "Your Full Name", text: $name)
                        .padding(.bottom, 10)

                    StandardTextFieldView(
                        title: "Email",
                        text: $email,
                        validationState: emailValidationState
                    )
                        .padding(.bottom, 10)

                    if let emailAvailabilityError {
                        Text(emailAvailabilityError)
                            .font(.caption)
                            .foregroundColor(AppColors.bearCandleRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 4)
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
                        title: "Password",
                        text: $password,
                        isSecure: true,
                        validationState: passwordValidationState
                    )
                        .padding(.bottom, 10)

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

                    if !confirmPassword.isEmpty {
                        HStack(spacing: 7) {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(passwordMatchColor)

                            Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                                .font(.caption)
                                .foregroundColor(passwordMatchColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                    }

                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
            .onChange(of: email) { _, _ in
                emailAvailabilityError = nil
            }
            .onAppear {
                if name.isEmpty {
                    name = data.name
                }
                if email.isEmpty {
                    email = data.email
                }
                if password.isEmpty {
                    password = data.password
                }
            }
            .platformNavigationBarBackground(AppColors.gradientBackgroundDark)
            .platformNavigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
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
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                StandardActionButtonFullWidth(
                    title: isCheckingAvailability ? "Checking..." : "Continue",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark
                ) {
                    Task { await validateAvailabilityAndContinue() }
                }
                .disabled(!isFormValid || isCheckingAvailability)
                .opacity((isFormValid && !isCheckingAvailability) ? 1.0 : 0.5)
            }
            .background(Color.clear)
        }
    }

    @MainActor
    private func validateAvailabilityAndContinue() async {
        guard !isCheckingAvailability else { return }
        emailAvailabilityError = nil
        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        do {
            let response = try await rlAppState.realApi.checkEmailAvailability(email: normalizedEmail)
            guard response.available else {
                emailAvailabilityError = response.detail
                return
            }

            data.name = normalizedName
            data.email = normalizedEmail
            data.password = password
            path.append(.username)
        } catch {
            if case APIError.badRequest(let detail) = error {
                emailAvailabilityError = detail
            } else {
                emailAvailabilityError = "We couldn't verify this email right now. Please try again."
            }
        }
    }
}
