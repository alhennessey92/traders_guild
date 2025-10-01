//
//  TextBoxView.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
import SwiftUI

/// Generic full-width button for login/signup
struct StandardTextFieldView: View {
    let title: String                 // Placeholder / label
    @Binding var text: String         // Two-way binding
    var isSecure: Bool = false        // Password field?
    // Track focus
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack (alignment: .leading){
            if text.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)   // placeholder color
                    .padding(.leading, 12)
            }
            
            // TextField vs SecureField
            if isSecure {
                SecureField("", text: $text)
                    .font(.body)
                    .textInputAutocapitalization(.never) // email, username safe
                    .autocorrectionDisabled()
                    .foregroundColor(AppColors.whiteText)
                    .accentColor(AppColors.whiteText)
                    .focused($isFocused)
                    .padding(.leading, 12)
                    
            } else {
                TextField("", text: $text)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(AppColors.whiteText)
                    .accentColor(AppColors.whiteText)
                    .focused($isFocused)
                    .padding(.leading, 12)
                    
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.unhighlightedTextBoxBackground)
                .opacity(isFocused ? 1.0 : 0.6)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        StandardTextFieldView(title: "Email", text: .constant(""))
        StandardTextFieldView(title: "Password", text: .constant(""), isSecure: true)
    }
}
