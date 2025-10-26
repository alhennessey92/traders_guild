//
//  ContentView.swift
//  traders_guild
//
//  Created by Al Hennessey on 22/09/2025.
//
import SwiftUI
struct ContentView: View {
    @State private var path: [SignupStep] = []   // navigation path
    @State private var data = SignupData()
    @EnvironmentObject var appState: AppState// shared signup data // change to app state

    var body: some View {
        
        
        if let _ = appState.currentUser {
            MainView()
        }  else {
            // 👋 No user, show the signup flow
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
}
