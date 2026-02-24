//
//  WelcomeView.swift
//  traders_guild
//

import SwiftUI

struct WelcomeView: View {
    @Binding var path: [RLSignupStep]
    @Binding var data: RLSignupData
    @EnvironmentObject var RLAppState: RLAppState

    @State private var opacity: Double = 0

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
                    Button {
                        RLAppState.showInfo("Apple sign-in will be enabled in an upcoming release.")
                    } label: {
                        LoginButton(
                            title: "Sign in with Apple",
                            iconName: "apple.logo",
                            backgroundColor: AppColors.whiteText.opacity(0.8),
                            foregroundColor: AppColors.gradientBackgroundDark
                        )
                    }

                    HStack(alignment: .center) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)

                        Text("OR")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 8)

                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
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
                        .background(Color.gray.opacity(0.5))

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
    }
}
