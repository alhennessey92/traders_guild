//
//  SigninEmail.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//
import SwiftUI


struct SigninEmailView: View {
    // MARK: - State
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @Environment(\.dismiss) var dismiss
    
    // Validate form before allowing next progression
    var isFormValid: Bool {
        !username.isEmpty &&
        password.count >= 6
    }

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
                    Text("Sign In")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    // Email TextField
                    StandardTextFieldView(title: "Email or Username", text: $username)
                        .padding(.bottom, 10)
                    
                    
                    StandardTextFieldView(title: "Password", text: $password, isSecure: true)
                        .padding(.bottom, 10)
                        
                    
                    VStack(spacing: 0) {
                        Divider()
                            .frame(height: 1)

                            .background(Color.gray.opacity(0.3)) // color
                    }
                    .padding(.horizontal, 16)  // horizontal inset
                    .padding(.top, 16)
                    
                    // Login button
                    // Login button
                    NavigationLink(destination: TestView()) {
                        StandardButton(
                            title: "Sign In",
                            backgroundColor: AppColors.whiteText,
                            foregroundColor: AppColors.gradientBackgroundDark
                            
                        ){}
                    }
                    .frame(maxWidth: .infinity)
//                    .disabled(!isFormValid) // ✅ disable until valid
//                    .opacity(isFormValid ? 1.0 : 0.5)
                    
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0){
                    
                    Divider()
                        .frame(height: 1)                  // thickness
                        .background(Color.gray.opacity(0.3)) // color
                    
                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot your password?")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center) // full width
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                }
                
                
                
            }

        }
            
        
    }
}

//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        SigninEmailView()
//    }
//}
