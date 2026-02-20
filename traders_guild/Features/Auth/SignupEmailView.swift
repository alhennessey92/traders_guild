//
//  SignupEmailView.swift
//  traders_guild
//

import SwiftUI

struct SignupEmailView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

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

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Step 1 of 6")
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

                    StandardTextFieldView(title: "Display name", text: $name)
                        .padding(.bottom, 10)

                    StandardTextFieldView(title: "Email", text: $email)
                        .padding(.bottom, 10)

                    Text("Password: 8-72 chars, with uppercase, lowercase, and a number.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.bottom, 5)

                    StandardTextFieldView(title: "Password", text: $password, isSecure: true)
                        .padding(.bottom, 10)

                    StandardTextFieldView(title: "Confirm Password", text: $confirmPassword, isSecure: true)
                        .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(Color.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    StandardActionButtonFullWidth(
                        title: "Continue",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        data.name = normalizedName
                        data.email = normalizedEmail
                        data.password = password
                        path.append(.username)
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)

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
        }
    }
}
