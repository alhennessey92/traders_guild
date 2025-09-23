//
//  SignupTopicsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

// Step 1: Collect basic account info
struct SignupTopicsView: View {
    @Binding var data: SignupData
    @Binding var path: [SignupStep]
    
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
                    Text("Ok \(data.username), what Topics are you interested in?")
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
                            title: "Next",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark,
                            action:{
                                
                                // Handle validation of username
                                data.username = username
                                path.append(.guild)
                            }
                        )
                        .padding(.top)
                        .padding(.trailing)
                        .disabled(username.isEmpty) // ✅ only enabled when not empty
                        .opacity(username.isEmpty ? 0.6 : 1.0)
                    }
                }
                
                
                
            }

        }
            
        
    }
}

#Preview {
    SignupTopicsView(
        data: .constant(SignupData(
            name: "Preview User",
            email: "test@example.com",
            dob: Date(),
            password: "password123",
            username: "alhennessey92"
        )),
        path: .constant([.topics]) // starting at topics step
    )
}
