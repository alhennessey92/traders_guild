//
//  TransitionView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
//  Handle transition from the end of the signup process to the rootview

import SwiftUI

struct TransitionView: View {
    @EnvironmentObject var session: SessionStore
    @State private var scale: CGFloat = 1.0        // pulsing text
    @State private var fadeIn: Bool = false      // fade in/out for view
    @State private var opacity: Double = 1.0       // fade out full screen

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack{
                VStack{
                    Text("Welcome to")
                        .font(.title2) // smaller
                        .foregroundColor(AppColors.greyText)
                    
                    Text("Traders Guild")
                        .font(AppFonts.title(size: 40))
                        
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.whiteText)
                }
                .multilineTextAlignment(.center)
                .scaleEffect(scale)
                .onAppear {
                    // Fade in both view and text
                    withAnimation(.easeIn(duration: 2.0)) {
                        fadeIn = true
                        opacity = 1
                    }

                    // Pulsing animation for text
                    withAnimation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.1
                    }

                    // After 6 seconds, fade out the whole screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            fadeIn = false
                            opacity = 0
                        }

                        // After fade completes, show RootView
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            session.finishWelcome()
                        }
                    }
                }
                .opacity(opacity)
                
                
            }
            .opacity(fadeIn ? 1 : 0)
            .animation(.easeIn(duration: 1.5), value: fadeIn)
            
        }
        .onAppear {
            fadeIn = true
        }
        
        .onDisappear {
            fadeIn = false // reset so it can fade in next time
        }
        // apply fade-out to entire view
    }
}

#Preview {
    TransitionView()
        .environmentObject(SessionStore())
}

//import SwiftUI
//
//struct TransitionView: View {
//    @EnvironmentObject var session: SessionStore
//    @State private var scale: CGFloat = 1.0
//    @State private var fadeIn: Bool = false
//    @State private var opacity: Double = 1.0
//
//    
//    var body: some View {
//        ZStack {
//            LinearGradient(
//                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .ignoresSafeArea()
//            
//            Text("Welcome to Traders Guild")
//                .font(.largeTitle)
//                .fontWeight(.heavy)
//                .foregroundColor(AppColors.whiteText)
//                .scaleEffect(scale)
//                .onAppear {
//                    // Start pulsing animation
//                    withAnimation(
//                        .easeInOut(duration: 1.2)
//                        .repeatForever(autoreverses: true)
//                    ) {
//                        scale = 1.1
//                    }
//                    
//                    // After 6 seconds → move to root
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
//                        
//                        session.finishWelcome()
////                        if let user = session.currentUser {
////                            // 🚀 switch to main app
////                            session.setUser(user) // triggers ContentView to show MainAppView
////                        }
//                    }
//                }
//                .opacity(fadeIn ? 1 : 0)
//                .animation(.easeIn(duration: 1.5), value: fadeIn)
//        }
//        .onAppear {
//            fadeIn = true
//            
//        }
//        
//        .onDisappear {
//            fadeIn = false
//        }
//    }
//}
//
//#Preview {
//    TransitionView()
//}

