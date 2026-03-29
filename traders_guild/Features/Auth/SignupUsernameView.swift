//
//  SignupUsernameView.swift
//  traders_guild
//

import SwiftUI

struct SignupUsernameView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var username: String = ""
    @State private var usernameAvailabilityError: String?
    @State private var isCheckingAvailability: Bool = false

    private var normalizedUsername: String {
        RLAuthValidator.trimmed(username)
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidUsername(normalizedUsername)
    }

    private var usernameValidationState: StandardTextFieldValidationState {
        usernameAvailabilityError == nil ? .neutral : .invalid
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Step 2 of 6")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    HStack(spacing: 6) {
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                    }
                    .padding(.horizontal, 20)

                    Text("Choose your username")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    StandardTextFieldView(
                        title: "Username",
                        text: $username,
                        validationState: usernameValidationState
                    )
                        .padding(.bottom, 10)

                    if let usernameAvailabilityError {
                        Text(usernameAvailabilityError)
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.bearCandleRed)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 4)
                    }

                    Text("3-50 characters. Use letters, numbers, dots, underscores, or hyphens.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(AppColors.surfaceGray30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .frame(height: 1)
                        .background(AppColors.surfaceGray30)

                    HStack {
                        Spacer()
                        StandardActionButton(
                            title: isCheckingAvailability ? "Checking..." : "Next",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark
                        ) {
                            Task { await validateAvailabilityAndContinue() }
                        }
                        .disabled(!isFormValid || isCheckingAvailability)
                        .opacity((isFormValid && !isCheckingAvailability) ? 1.0 : 0.5)
                        .padding(.top)
                        .padding(.trailing)
                    }
                }
                .background(AppColors.sheetBackground)
            }
        }
        .onChange(of: username) { _, _ in
            usernameAvailabilityError = nil
        }
        .onAppear {
            if username.isEmpty {
                username = data.username
            }
        }
    }

    @MainActor
    private func validateAvailabilityAndContinue() async {
        guard !isCheckingAvailability else { return }
        usernameAvailabilityError = nil
        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        do {
            let response = try await rlAppState.realApi.checkUsernameAvailability(username: normalizedUsername)
            guard response.available else {
                usernameAvailabilityError = response.detail
                return
            }

            data.username = normalizedUsername
            path.append(.basics)
        } catch {
            if case APIError.badRequest(let detail) = error {
                usernameAvailabilityError = detail
            } else {
                usernameAvailabilityError = "We couldn't verify this username right now. Please try again."
            }
        }
    }
}
