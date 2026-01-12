//
//  SigninEmail.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//
//
//  SigninEmail.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

import SwiftUI

struct SigninEmailView: View {
    // MARK: - State
    
    @EnvironmentObject var RLAppState: RLAppState
    
    
    
    //@EnvironmentObject var appState: AppState
    
    @State private var emailOrUsername: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoggingIn: Bool = false
    
    @Environment(\.dismiss) var dismiss
    
    // Validate form before allowing login
    var isFormValid: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            
            ScrollView(showsIndicators: false) {
                VStack {
                    // Description
                    Text("Sign In")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    // Email/Username TextField
                    StandardTextFieldView(title: "Email or Username", text: $emailOrUsername)
                        .padding(.bottom, 10)
                        .disabled(isLoggingIn)
                    
                    // Password TextField
                    StandardTextFieldView(title: "Password", text: $password, isSecure: true)
                        .padding(.bottom, 10)
                        .disabled(isLoggingIn)
                    
                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(Color.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // ✅ Login button with AppState integration
                    StandardButton(
                        title: isLoggingIn ? "Signing In..." : "Sign In",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task {
                            await handleLogin()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid || isLoggingIn)
                    .opacity(isFormValid && !isLoggingIn ? 1.0 : 0.5)
                    .overlay {
                        if isLoggingIn {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gradientBackgroundDark))
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.leading, 40)
                        }
                    }
                    
                    Spacer()
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
                    .disabled(isLoggingIn)
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
                    
                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot your password?")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    .disabled(isLoggingIn)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLogin() async {
        isLoggingIn = true
        
        do {
            try await RLAppState.login(email: emailOrUsername, password: password)
            
            // ✅ Wait a tiny moment for the sheet to present
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // ✅ Dismiss back to root
            dismiss()
            
        } catch {
            // ✅ Error automatically shown by global alert
            isLoggingIn = false
        }
    }
}

//#Preview {
//    NavigationStack {
//        SigninEmailView()
//            .environmentObject(AppState())
//    }
//}


