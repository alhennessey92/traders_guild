//
//  SignupTopicsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

// Step 1: Collect basic account info
struct SignupBasicsView: View {
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
                    Text("Ok \(data.username), let's take a look at the Basics")
                        .font(.title.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    
                    LearnBasicsBox(title: "Guilds", iconName: "shield.pattern.checkered", description: "The basics are part of this and i will describe all the stuff relating to the app for the users to lear")
                    
                    LearnBasicsBox(title: "Markers", iconName: "star.bubble", description: "The basics are part of this and i will describe all the stuff relating to the app for the users to lear")
                    
                    LearnBasicsBox(title: "Reputation", iconName: "globe", description: "The basics are part of this and i will describe all the stuff relating to the app for the users to lear")
                    
                    LearnBasicsBox(title: "Social", iconName: "person.line.dotted.person", description: "The basics are part of this and i will describe all the stuff relating to the app for the users to lear")
                    
                    LearnBasicsBox(title: "Future", iconName: "chart.line.uptrend.xyaxis", description: "The basics are part of this and i will describe all the stuff relating to the app for the users to lear")
                    
                    
                    
                    
                    
                    
                        
                    
//                    VStack(spacing: 0) {
//                        Divider()
//                            .frame(height: 1)
//
//                            .background(Color.gray.opacity(0.3)) // color
//                    }
//                    .padding(.horizontal, 16)  // horizontal inset
//                    .background(Color.blue.opacity(0.2))
                    
                    
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
//                        
                    }
                }
                .background(AppColors.gradientBackgroundLight)
                
                
                
            }
            

        }
            
        
    }
}

//#Preview {
//    SignupBasicsView(
//        data: .constant(SignupData(
//            name: "Preview User",
//            email: "test@example.com",
//            dob: Date(),
//            password: "password123",
//            username: "alhennessey92"
//        )),
//        path: .constant([.guild]) // starting at topics step
//    )
//}
