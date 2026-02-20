//
//  SignupUsernameView.swift
//  traders_guild
//

import SwiftUI

struct SignupUsernameView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]

    @State private var username: String = ""

    private var normalizedUsername: String {
        RLAuthValidator.trimmed(username)
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidUsername(normalizedUsername)
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Choose your username")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)

                    StandardTextFieldView(title: "Username", text: $username)
                        .padding(.bottom, 10)

                    Text("3-50 characters. Use letters, numbers, dots, underscores, or hyphens.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(Color.gray.opacity(0.3))
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
                        .background(Color.gray.opacity(0.3))

                    HStack {
                        Spacer()
                        StandardActionButton(
                            title: "Next",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark
                        ) {
                            data.username = normalizedUsername
                            path.append(.basics)
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.top)
                        .padding(.trailing)
                    }
                }
                .background(AppColors.sheetBackground)
            }
        }
        .onAppear {
            if username.isEmpty {
                username = data.username
            }
        }
    }
}
