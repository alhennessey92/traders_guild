//
//  ForgotPasswordView.swift
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


struct ForgotPasswordView: View {
    // MARK: - State
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    
    @Environment(\.dismiss) var dismiss

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
                    Text("Reset your Password")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    
                    // Email
                    StandardTextFieldView(title: "Email or Username", text: $username)
                        .padding(.bottom, 10)
                    
                    // Email TextField
                    StandardTextFieldView(title: "New Password", text: $password, isSecure: true)
                        .padding(.bottom, 10)
                    
                    StandardTextFieldView(title: "Confirm Password", text: $passwordConfirm, isSecure: true)
                        
                    
                    
                    
                    // Login button
                    NavigationLink(destination: TestView()) {
                        StandardButton(
                            title: "Reset",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark
                            
                        ){}
                    }
                    
                    
                    Spacer() // push content up a bit
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
                   
                }
                
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                      
                }
                
            }
           

        }
            
        
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
    }
}
