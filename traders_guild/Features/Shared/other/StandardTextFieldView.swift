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
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var isSecureTextVisible = false
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

    private var secureContentType: UITextContentType? {
        if normalizedTitle.contains("new password") || normalizedTitle.contains("confirm password") {
            return .newPassword
        }
        if normalizedTitle.contains("password") {
            return .password
        }
        return nil
    }

    private var strokeColor: Color {
        switch validationState {
        case .neutral:
            return isFocused ? AppColors.whiteText.opacity(0.45) : AppColors.standardSearchFieldStroke
        case .valid:
            return AppColors.bullCandleGreen.opacity(isFocused ? 0.95 : 0.75)
        case .invalid:
            return AppColors.bearCandleRed.opacity(isFocused ? 0.95 : 0.75)
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isSecure {
                    // Both fields exist simultaneously; opacity swap avoids
                    // the view-destroy/create flash that if/else causes.
                    ZStack {
                        TextField(title, text: $text)
                            .textContentType(secureContentType)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .opacity(isSecureTextVisible ? 1 : 0)
                        SecureField(title, text: $text)
                            .textContentType(secureContentType)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .opacity(isSecureTextVisible ? 0 : 1)
                    }
                } else {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(isDisplayNameField ? .words : .never)
                        .textContentType(isEmailField ? .emailAddress : (isUsernameField ? .username : (isTokenField ? .oneTimeCode : nil)))
                        .keyboardType(isEmailField ? .emailAddress : .default)
                        .autocorrectionDisabled()
                }
            }
            .focused($isFocused)

            if isSecure {
                Button {
                    isSecureTextVisible.toggle()
                    isFocused = true
                } label: {
                    Image(systemName: isSecureTextVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.55))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.body)
        .foregroundColor(AppColors.whiteText)
        .accentColor(AppColors.whiteText)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.standardSearchFieldFill)
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
