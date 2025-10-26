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
    @State private var path: [SignupStep] = []
    @State private var data = SignupData()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        // 👋 No user or no guild, show the signup flow
        NavigationStack(path: $path) {
            WelcomeView(path: $path, data: $data)
                .navigationDestination(for: SignupStep.self) { step in
                    switch step {
                    case .accountInfo:
                        SignupEmailView(data: $data, path: $path)
                    case .username:
                        SignupUsernameView(data: $data, path: $path)
                    case .basics:
                        SignupBasicsView(data: $data, path: $path)
                    case .guild:
                        SignupGuildView(data: $data, path: $path)
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
