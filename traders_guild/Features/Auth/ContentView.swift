//
//  ContentView.swift
//  traders_guild
//
//  Created by Al Hennessey on 22/09/2025.
//

//
//  ContentView.swift
//  traders_guild
//
//  Created by Al Hennessey on 22/09/2025.
//
import SwiftUI

struct ContentView: View {
    @State private var path: [RLSignupStep] = []
    @State private var data = RLSignupData()
    @EnvironmentObject var RLAppState: RLAppState
    @State private var showResetFromDeepLink: Bool = false
    @State private var showVerifyFromDeepLink: Bool = false
    
    
    //@EnvironmentObject var appState: AppState
    
    var body: some View {
        // 👋 No user or no guild, show the signup flow
        NavigationStack(path: $path) {
            WelcomeView(path: $path, data: $data)
                .navigationDestination(for: RLSignupStep.self) { step in
                    switch step {
                    case .accountInfo:
                        SignupEmailView(data: $data, path: $path)
                    case .username:
                        SignupUsernameView(data: $data, path: $path)
                    case .basics:
                        SignupBasicsView(data: $data, path: $path)
                    case .interests:
                        SignupInterestsView(data: $data, path: $path)
                    case .guild:
                        SignupGuildView(data: $data, path: $path)
                    case .profile:
                        SignupProfileSetupView(data: $data, path: $path)
                    case .emailVerification:
                        EmailVerificationView(
                            userEmail: data.email,
                            onContinue: {
                                RLAppState.completeOnboardingAndEnterApp()
                            }
                        )
                    }
                }
        }
        .onAppear {
            showResetFromDeepLink = RLAppState.pendingPasswordResetToken != nil
        }
        .onChange(of: RLAppState.pendingPasswordResetToken) { _, newValue in
            showResetFromDeepLink = newValue != nil
        }
        .fullScreenCover(isPresented: $showResetFromDeepLink, onDismiss: {
            RLAppState.setPendingPasswordResetToken(nil)
        }) {
            NavigationStack {
                ForgotPasswordView(
                    initialToken: RLAppState.pendingPasswordResetToken,
                    launchedFromDeepLink: true
                )
                .environmentObject(RLAppState)
            }
        }
        .onChange(of: RLAppState.pendingEmailVerificationToken) { _, newValue in
            if let token = newValue, !token.isEmpty {
                Task {
                    do {
                        let verified = try await RLAppState.verifyEmail(token: token)
                        if verified {
                            RLAppState.showSuccess("Email verified successfully!")
                        } else {
                            RLAppState.showError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid or expired verification token."]))
                        }
                    } catch {
                        RLAppState.showError(error)
                    }
                    RLAppState.setPendingEmailVerificationToken(nil)
                }
            }
        }
    }
}
//import SwiftUI
//
//struct ContentView: View {
//    @State private var path: [SignupStep] = []
//    @State private var data = SignupData()
//    @EnvironmentObject var appState: AppState
//    
//    var body: some View {
//        ZStack {
//            if let _ = appState.currentUser {
//                MainView()
//            } else {
//                // 👋 No user, show the signup flow
//                NavigationStack(path: $path) {
//                    WelcomeView(path: $path, data: $data)
//                        .navigationDestination(for: SignupStep.self) { step in
//                            switch step {
//                            case .accountInfo:
//                                SignupEmailView(data: $data, path: $path)
//                            case .username:
//                                SignupUsernameView(data: $data, path: $path)
//                            case .basics:
//                                SignupBasicsView(data: $data, path: $path)
//                            case .guild:
//                                SignupGuildView(data: $data, path: $path)
//                            }
//                        }
//                }
//            }
//        }
//        // ✅ Global Alert
//        .alert(
//            "Error",
//            isPresented: Binding(
//                get: { appState.errorMessage != nil },
//                set: { if !$0 { appState.errorMessage = nil } }
//            )
//        ) {
//            Button("OK", role: .cancel) {
//                appState.errorMessage = nil
//            }
//        } message: {
//            if let errorMessage = appState.errorMessage {
//                Text(errorMessage)
//            }
//        }
//        // ✅ Guild Selection Sheet
//        .sheet(isPresented: $appState.showGuildSelectionSheet) {
//            GuildSelectionSheet()
//                .presentationDetents([.medium, .large])
//                .presentationDragIndicator(.visible)
//        }
//        
//    }
//}
