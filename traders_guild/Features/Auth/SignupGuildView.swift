//
//  SignupGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//

import SwiftUI

// Step 1: Collect basic account info
struct SignupGuildView: View {
    @Binding var data: SignupData
    @Binding var path: [SignupStep]
    @EnvironmentObject var session: SessionStore
    // MARK: - State
    @State private var username: String = ""
    
    

    var body: some View {
        
        ZStack {
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView (showsIndicators: false){
                
                VStack() {
                    // Description
                    Text("Now you got the info, let's join a Guild!")
                        .font(.title.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    
                    
                    
                    
                    
                        
                    
                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)

                            .background(Color.gray.opacity(0.3)) // color
                    }
                    .padding(.horizontal, 16)  // horizontal inset
                    .background(Color.blue.opacity(0.2))
                    
                    
                }
                .frame(maxWidth: .infinity, alignment: .top)
              
                
            }
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() } // Go back
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
                VStack(spacing: 0){
                    
                    Divider()
                        .frame(height: 1)                  // thickness
                        .background(Color.gray.opacity(0.3)) // color
                    
                    HStack{
                        Spacer()
                        StandardActionButton(
                            title: "Finish",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark,
                            
                        ){
                            // Save signup data → create User object
                            let user = User(id: UUID().uuidString, name: data.name, email: data.email)
                            session.setUser(user) // ✅ This flips the root to MainAppView
                            session.showingTransition = true // trigger the TransitionView
                        }
                        .padding(.top)
                        .padding(.trailing)
//                        .disabled(username.isEmpty) // ✅ only enabled when not empty
//                        .opacity(username.isEmpty ? 0.6 : 1.0)
                    }
                }
                
                
                
            }

        }
            
        
    }
}
