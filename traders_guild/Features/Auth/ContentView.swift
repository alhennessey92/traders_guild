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
    @EnvironmentObject var session: SessionStore// shared signup data

    var body: some View {
        if let _ = session.currentUser {
            if session.showingTransition {
                TransitionView()
            } else {
                RootView()
            }
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
