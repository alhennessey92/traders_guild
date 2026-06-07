//
//  AppleProfileCompletionView.swift
//  traders_guild
//
//  Collects required profile fields (display name) for new
//  Apple Sign In users before continuing into the shared onboarding pipeline.
//

import SwiftUI

struct AppleProfileCompletionView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var name: String = ""

    private var normalizedName: String {
        RLAuthValidator.trimmed(name)
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidDisplayName(normalizedName)
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

                    Text("Complete your profile")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 6)
                        .padding(.leading, 20)

                    Text("We just need a few details to get you started.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    StandardTextFieldView(title: "Your Full Name", text: $name)
                        .padding(.bottom, 16)

                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
            .onAppear {
                if name.isEmpty {
                    name = data.name
                }
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
        .keyboardPinnedBottomInset(background: AnyView(AuthKeyboardFooterChrome())) {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                StandardActionButtonFullWidth(
                    title: "Continue",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark
                ) {
                    data.name = normalizedName
                    path.append(.username)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .background(Color.clear)
        }
    }
}
