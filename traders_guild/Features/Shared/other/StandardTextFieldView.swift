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

enum StandardTextFieldValidationState {
    case neutral
    case valid
    case invalid
}

/// Generic full-width button for login/signup
struct StandardTextFieldView: View {
    let title: String                 // Placeholder / label
    @Binding var text: String         // Two-way binding
    var isSecure: Bool = false        // Password field?
    var validationState: StandardTextFieldValidationState = .neutral
    // Track focus
    @FocusState private var isFocused: Bool
    
    private var normalizedTitle: String {
        title.lowercased()
    }

    private var isEmailField: Bool {
        normalizedTitle.contains("email")
    }

    private var isUsernameField: Bool {
        normalizedTitle.contains("username")
    }

    private var isDisplayNameField: Bool {
        normalizedTitle.contains("display name") || normalizedTitle == "name"
    }

    private var isTokenField: Bool {
        normalizedTitle.contains("token")
    }

    private var strokeColor: Color {
        switch validationState {
        case .neutral:
            return isFocused ? AppColors.whiteText.opacity(0.45) : AppColors.whiteText.opacity(0.15)
        case .valid:
            return AppColors.bullCandleGreen.opacity(isFocused ? 0.95 : 0.75)
        case .invalid:
            return AppColors.bearCandleRed.opacity(isFocused ? 0.95 : 0.75)
        }
    }
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(title, text: $text)
                    .textInputAutocapitalization(isDisplayNameField ? .words : .never)
                    .textContentType(isEmailField ? .emailAddress : (isUsernameField ? .username : (isTokenField ? .oneTimeCode : nil)))
                    .keyboardType(isEmailField ? .emailAddress : .default)
                    .autocorrectionDisabled()
            }
        }
        .font(.body)
        .foregroundColor(AppColors.whiteText)
        .accentColor(AppColors.whiteText)
        .focused($isFocused)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(strokeColor, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        StandardTextFieldView(title: "Email", text: .constant(""))
        StandardTextFieldView(title: "Password", text: .constant(""), isSecure: true)
    }
}
