//
//  SignupUsernameView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
//
//  SignUpEmailView.swift
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


struct SignupUsernameView: View {
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
                    Text("Hi, \(data.name)! Please choose a Username")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    // Email TextField
                    StandardTextFieldView(title: "Username", text: $username)
                        .padding(.bottom, 10)
                    
                    
                    
                    
                        
                    
                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)

                            .background(Color.gray.opacity(0.3)) // color
                    }
                    .padding(.horizontal, 16)  // horizontal inset
                    .padding(.top, 16)
                    
                    // Login button
                    
                    
                    Spacer() // push content up a bitthis is a test for tpying and seeing if anything will break
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
                                path.append(.basics)
                            }
                        )
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

#Preview {
    SignupUsernameView(
        data: .constant(SignupData(
            name: "Preview User",
            email: "test@example.com",
            dob: Date(),
            password: "password123",
            username: "alhennessey92"
        )),
        path: .constant([.username]) // starting at topics step
    )
}

