//
//  WelcomeView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI
import AuthenticationServices

// First screen the user sees
// Offers login via email, signup, or Apple Sign-In
struct WelcomeView: View {
    @Binding var path: [SignupStep]
    @Binding var data: SignupData
    @EnvironmentObject var session: SessionStore // Observe current user
    
//    let onTap: () -> Void
    
    var body: some View {
        
            
        ZStack {
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("Traders Guild")
                    .font(AppFonts.title(size: 66))
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(0)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading) // full width
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                    .padding(.leading, 20)
                   

                    
                
                    
                    
//                    Text("Guild")
//                        .font(AppFonts.title(size: 68))
//                        .foregroundColor(AppColors.whiteText)
//                        .multilineTextAlignment(.leading)
//                        .frame(maxWidth: .infinity, alignment: .topLeading) // full width
//                        .fixedSize(horizontal: false, vertical: true)
//                        .background()
                    
                Spacer()
                
                VStack(spacing: 10) {
                    
                    // Apple Sign In
                    NavigationLink(destination: TestView()) {
                        LoginButton(
                            title: "Sign in with Apple",
                            iconName: "apple.logo",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark,
                            
                        )
                    }
                    
                    
                    // OR Divider
                    HStack(alignment: .center) {
                        Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)

                        Text("OR")              // middle text
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 8)

                        Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical)
                    
                    
                    
                    // Email Sign in
                    NavigationLink(destination: SigninEmailView()) {
                        LoginButton(
                            title: "Sign in with Email",
                            iconName: "envelope.fill",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark,
                            // no action needed
                        )
                    }
                    
                    
                    //Google Sign in
                    NavigationLink(destination: TestView()) {
                        LoginButton(
                            title: "Sign in with Google",
                            iconName: "g.circle.fill",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark,
                            
                        )
                    }
                    
                    
                    
                    
//                        // Apple Sign-In button (mock implementation for now)
//                        Button("Sign in with Apple") {
//                            // In a real app, implement AppleAuth here
//                            // For now, create a mock user and set session
//                            let user = User(id: UUID().uuidString, name: "Apple User", email: "apple@id.com", token: "appleToken")
//                            session.setUser(user)
//                        }
//                        .buttonStyle(.borderedProminent)
                }
//                    .background(AppColors.whiteText.opacity(0.1))
                // Title
                
                
                Divider()
                    .frame(height: 1)                  // thickness
                    .background(Color.gray.opacity(0.5)) // color
                
                
                Text("By signing in, you agree to our Terms Of Use, Privacy Policy and Cookies Policy")
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(0)
                    .frame(maxWidth: .infinity, alignment: .center) // full width
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 0)
//                        .background(AppColors.whiteText.opacity(0.1))
                
                Spacer()
                
                
                
                
                VStack(spacing: 10) {
                    
                    Divider()
                        .frame(height: 1)                  // thickness
                        .background(Color.gray.opacity(0.5)) // color
                    
    
                    HStack {
                        Text("Don't have an account?")
                        
                        
                        Text("Sign up Here")
                            .bold()
                            .foregroundColor(AppColors.accentColor)
                            .onTapGesture {
                                path.append(.accountInfo) // same idea
                            }
                        
                    }
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center) // full width
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    
                }
                
            }
            .padding()
        }
        
    }
    
}
//#Preview {
//    WelcomeView()
//        .environmentObject(SessionStore()) // fake logged-out session
//}
