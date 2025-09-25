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


struct SignupEmailView: View {
    @Binding var data: SignupData
    @Binding var path: [SignupStep]
    // MARK: - State
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var dob: Date = Date()
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    

    // Validate form before allowing next progression
    var isFormValid: Bool {
        !name.isEmpty &&
        email.contains("@") &&
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
                    Text("Sign Up with Email")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 20)
                        .padding(.leading, 20)
                    
                    // Email TextField
                    StandardTextFieldView(title: "Name", text: $name)
                        .padding(.bottom, 10)
                    
                    StandardTextFieldView(title: "Email", text: $email)
                        .padding(.bottom, 10)
                    
                    StandardDatePickerView(title: "Date of Birth", date: $dob)
                        .padding(.bottom, 10)
                    
                    Text("Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(0)
                        .frame(maxWidth: .infinity, alignment: .center) // full width
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                    
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
                    StandardActionButtonFullWidth(
                        title: "Sign Up",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark,
                        action:{
                            data.name = name
                            data.email = email
                            data.dob = dob
                            data.password = password
                            path.append(.username)
                        }
                        
                    )
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
                    
//                    Divider()
//                        .frame(height: 1)                  // thickness
//                        .background(Color.gray.opacity(0.3)) // color
//                    
//                    NavigationLink(destination: ForgotPasswordView()) {
//                        Text("Forgot your password?")
//                            .font(AppFonts.smallNotice())
//                            .foregroundColor(AppColors.whiteText)
//                            .multilineTextAlignment(.center)
//                            .frame(maxWidth: .infinity, alignment: .center) // full width
//                            .fixedSize(horizontal: false, vertical: true)
//                            .padding()
//                    }
                }
                
                
                
            }

        }
            
        
    }
}

//#Preview {
//    @State var previewData = SignupData()
//    SignupEmailView(data: $previewData, onNext: {}, onBack: {})
//        .environmentObject(SessionStore())
//}
