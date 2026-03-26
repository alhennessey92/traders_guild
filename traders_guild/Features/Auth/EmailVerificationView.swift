//
//  EmailVerificationView.swift
//  traders_guild
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var RLAppState: RLAppState
    @Environment(\.dismiss) var dismiss

    @State private var isResending: Bool = false
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Timer?
    @State private var verificationCode: String = ""
    @State private var isVerifying: Bool = false
    @FocusState private var codeFieldFocused: Bool

    let userEmail: String
    let onContinue: () -> Void

    private var canResend: Bool {
        !isResending && resendCooldown == 0
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Verify your Email")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    // Envelope icon
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accentColor)
                        .padding(.bottom, 16)

                    Text("We've sent a verification code to:")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(userEmail)
                        .font(.body.bold())
                        .foregroundColor(AppColors.whiteText)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    Text("Check your inbox and enter the 5-character code to verify your email. This unlocks full access to Traders Guild, including joining and creating guilds.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Manual token entry section
                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(AppColors.surfaceGray30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    Text("Or enter your 5-character verification code:")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    // 5-character code input
                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { index in
                            let char = index < verificationCode.count
                                ? String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
                                : ""
                            Text(char)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.whiteText)
                                .frame(width: 48, height: 56)
                                .background(AppColors.surfaceWhite05)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            index < verificationCode.count
                                                ? AppColors.accentColor
                                                : AppColors.surfaceWhite10,
                                            lineWidth: index == verificationCode.count ? 2 : 1
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
                    .onTapGesture { codeFieldFocused = true }
                    .background(
                        TextField("", text: $verificationCode)
                            .focused($codeFieldFocused)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .opacity(0)
                            .onChange(of: verificationCode) { _, newValue in
                                let filtered = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
                                if filtered != newValue {
                                    verificationCode = filtered
                                }
                                if filtered.count == 5 {
                                    verifyWithCode()
                                }
                            }
                    )

                    if !verificationCode.isEmpty && verificationCode.count < 5 {
                        Text("\(5 - verificationCode.count) more character\(verificationCode.count == 4 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                            .padding(.bottom, 8)
                    }

                    if verificationCode.count == 5 {
                        Button {
                            verifyWithCode()
                        } label: {
                            LoginButton(
                                title: isVerifying ? "Verifying..." : "Verify Email",
                                iconName: "checkmark.seal.fill",
                                backgroundColor: AppColors.bullCandleGreen,
                                foregroundColor: AppColors.whiteText
                            )
                        }
                        .disabled(isVerifying)
                        .padding(.bottom, 12)
                    }

                    // Resend button
                    Button {
                        resendEmail()
                    } label: {
                        LoginButton(
                            title: resendCooldown > 0 ? "Resend in \(resendCooldown)s" : (isResending ? "Sending..." : "Resend Verification Email"),
                            iconName: "arrow.clockwise",
                            backgroundColor: canResend ? AppColors.accentColor : AppColors.surfaceGray30,
                            foregroundColor: AppColors.whiteText
                        )
                    }
                    .disabled(!canResend)
                    .padding(.bottom, 12)

                    // Continue button
                    Button {
                        onContinue()
                    } label: {
                        LoginButton(
                            title: "Continue without verifying",
                            iconName: "arrow.right",
                            backgroundColor: AppColors.unhighlightedButtonBackground,
                            foregroundColor: AppColors.whiteText
                        )
                    }

                    Text("You can verify later, but some features will be restricted until you do.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
            }
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
    }

    private func resendEmail() {
        isResending = true
        Task {
            do {
                try await RLAppState.resendVerificationEmail()
                await MainActor.run {
                    isResending = false
                    startResendCooldown()
                    RLAppState.showSuccess("Verification email sent!")
                }
            } catch {
                await MainActor.run {
                    isResending = false
                    RLAppState.showError(error)
                }
            }
        }
    }

    private func verifyWithCode() {
        let trimmed = verificationCode.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 5 else { return }
        guard !isVerifying else { return }
        codeFieldFocused = false
        isVerifying = true
        Task {
            do {
                let verified = try await RLAppState.verifyEmail(token: trimmed)
                await MainActor.run {
                    isVerifying = false
                    if verified {
                        RLAppState.showSuccess("Email verified successfully!")
                        onContinue()
                    } else {
                        verificationCode = ""
                        RLAppState.showError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid or expired code. Please request a new one."]))
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verificationCode = ""
                    RLAppState.showError(error)
                }
            }
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}
