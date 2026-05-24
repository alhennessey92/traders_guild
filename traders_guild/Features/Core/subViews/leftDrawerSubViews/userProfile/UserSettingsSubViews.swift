//
//  UserSettingsSubViews.swift
//  traders_guild
//
//  Comprehensive settings subviews for profile editing, account management,
//  help & support, blocked users, trading interests, and more.
//
//  FULLY INTEGRATED WITH BACKEND APIS
//  Created by Al Hennessey on 30/01/2026.
//

import SwiftUI
import UIKit


// ================================================================================================
// MARK: - Navigation State for Settings
// ================================================================================================

/// Centralized navigation state for settings flow
enum SettingsDestination: Hashable {
    case editProfile
    case avatarSelection
    case changeEmail
    case changePassword
    case dateOfBirth
    case tradingInterests
    case blockedUsers
    case dataPrivacy
    case pushNotifications
    case helpCenter
    case contactSupport
    case rateApp
    case termsPrivacy
    case termsOfService
    case privacyPolicy
    case communityGuidelines
    case legalInformation
    case about
    case leaveGuild
    case deleteAccount
}


// ================================================================================================
// MARK: - Edit Profile View
// ================================================================================================

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    // Form state
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var language: String = ""
    @State private var location: String = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showAvatarPicker = false
    @State private var showDiscardAlert = false
    @State private var hasChanges = false
    
    // Extended profile
    @State private var extendedProfile: RLUserProfileDTO?
    
    // Validation
    @State private var usernameError: String?
    @State private var displayNameError: String?
    @State private var displayNameValidationTask: Task<Void, Never>?
    @State private var usernameValidationTask: Task<Void, Never>?

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        usernameError == nil &&
        displayNameError == nil
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        SettingsSubViewHeader(
                            title: "Edit Profile",
                            onBack: {
                                if hasChanges {
                                    showDiscardAlert = true
                                } else {
                                    onBack()
                                }
                            }
                        )
                        
                        VStack(spacing: 24) {
                            // Avatar Section
                            VStack(spacing: 12) {
                                let currentUser = rlAppState.currentUser
                                ZStack(alignment: .bottomTrailing) {
                                    UnifiedMemberAvatar(
                                        username: displayName,
                                        avatarURL: currentUser?.avatarUrl,
                                        isOnline: {
                                            guard let currentUser else { return false }
                                            return rlAppState.effectiveOnlineStatus(
                                                userId: currentUser.id,
                                                fallback: currentUser.isOnline
                                            )
                                        }(),
                                        size: 100,
                                        showOnlineIndicator: false
                                    )
                                    
                                    Button(action: { showAvatarPicker = true }) {
                                        Circle()
                                            .fill(AppColors.accentColor)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppColors.onAccentForeground)
                                            )
                                    }
                                }
                                
                                Button(action: { showAvatarPicker = true }) {
                                    Text("Change Avatar")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.accentColor)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                // Display Name
                                SettingsTextField(
                                    title: "Display Name",
                                    placeholder: "Your display name",
                                    text: $displayName,
                                    icon: "person.fill",
                                    error: displayNameError
                                )
                                .onChange(of: displayName) { _, newValue in
                                    hasChanges = true
                                    displayNameValidationTask?.cancel()
                                    displayNameValidationTask = Task {
                                        try? await Task.sleep(nanoseconds: 250_000_000)
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run { validateDisplayName(newValue) }
                                    }
                                }
                                
                                // Username
                                SettingsTextField(
                                    title: "Username",
                                    placeholder: "username",
                                    text: $username,
                                    icon: "at",
                                    error: usernameError,
                                    prefix: "@"
                                )
                                .onChange(of: username) { _, newValue in
                                    hasChanges = true
                                    usernameValidationTask?.cancel()
                                    usernameValidationTask = Task {
                                        try? await Task.sleep(nanoseconds: 250_000_000)
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run { validateUsername(newValue) }
                                    }
                                }
                                
                                // Bio
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Bio")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.greyText)
                                    
                                    TextEditor(text: $bio)
                                        .frame(minHeight: 100)
                                        .padding(12)
                                        .background(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                        .foregroundColor(AppColors.whiteText)
                                        .onChange(of: bio) { _, _ in
                                            hasChanges = true
                                        }
                                    
                                    HStack {
                                        Spacer()
                                        Text("\(bio.count)/500")
                                            .font(.caption)
                                            .foregroundColor(bio.count > 500 ? .red : AppColors.greyText)
                                    }
                                }
                                
                                // Language
                                SettingsDropdownField(
                                    title: "Language",
                                    placeholder: "Preferred language",
                                    text: $language,
                                    icon: "globe",
                                    options: LocaleOptionCatalog.languages,
                                    displayValue: { LocaleOptionCatalog.languageLabel(for: $0) }
                                )
                                .onChange(of: language) { _, _ in
                                    hasChanges = true
                                }

                                // Location
                                SettingsDropdownField(
                                    title: "Location",
                                    placeholder: "Select country",
                                    text: $location,
                                    icon: "location.fill",
                                    options: LocaleOptionCatalog.countries,
                                    showsFlags: true,
                                    displayValue: { LocaleOptionCatalog.countryDisplay(for: $0) }
                                )
                                .onChange(of: location) { _, _ in
                                    hasChanges = true
                                }
                            }
                            .padding(.horizontal, 25)
                            
                            // Save Button
                            StandardActionButtonFullWidth(
                                title: "Save Changes",
                                backgroundColor: isValid && hasChanges ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                                foregroundColor: .white,
                                isLoading: isSaving,
                                isDisabled: !isValid || !hasChanges || isSaving,
                                action: saveProfile
                            )
                            .padding(.top, 10)

                            Spacer(minLength: 100)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTapAndDragBackground()
            }
        }
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarSelectionView(onBack: { showAvatarPicker = false })
                .environmentObject(rlAppState)
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) { onBack() }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
    
    // MARK: - Functions
    
    private func loadProfile() async {
        isLoading = true
        
        // Load basic user info
        if let user = rlAppState.currentUser {
            displayName = user.displayName
            username = user.username
        }
        
        // Load extended profile
        do {
            let profile = try await rlAppState.fetchExtendedProfile()
            extendedProfile = profile
            bio = profile.bio ?? ""
            language = LocaleOptionCatalog.languageCode(from: profile.language)
            location = LocaleOptionCatalog.countryCode(from: profile.location)
        } catch {
            print("Failed to load extended profile: \(error)")
        }
        
        isLoading = false
    }
    
    private func validateDisplayName(_ name: String) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            displayNameError = "Display name is required"
        } else if name.count < 2 {
            displayNameError = "Display name must be at least 2 characters"
        } else if name.count > 50 {
            displayNameError = "Display name must be less than 50 characters"
        } else {
            displayNameError = nil
        }
    }
    
    private func validateUsername(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            usernameError = "Username is required"
        } else if trimmed.count < 3 {
            usernameError = "Username must be at least 3 characters"
        } else if trimmed.count > 20 {
            usernameError = "Username must be less than 20 characters"
        } else if !trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            usernameError = "Username can only contain letters, numbers, and underscores"
        } else {
            usernameError = nil
        }
    }
    
    private func saveProfile() {
        guard isValid else { return }
        isSaving = true
        
        Task {
            do {
                // Update basic info (display name and username)
                let user = rlAppState.currentUser
                let newDisplayName = displayName != user?.displayName ? displayName : nil
                let newUsername = username != user?.username ? username : nil
                
                if newDisplayName != nil || newUsername != nil {
                    _ = try await rlAppState.updateBasicUserInfo(
                        displayName: newDisplayName,
                        username: newUsername
                    )
                }
                
                // Update extended profile (bio, language, and location)
                let hasBioChange = bio != (extendedProfile?.bio ?? "")
                let hasLanguageChange = language != LocaleOptionCatalog.languageCode(from: extendedProfile?.language)
                let hasLocationChange = location != LocaleOptionCatalog.countryCode(from: extendedProfile?.location)
                
                if hasBioChange || hasLanguageChange || hasLocationChange {
                    _ = try await rlAppState.updateUserProfile(
                        RLUserProfileUpdateRequest(
                            bio: hasBioChange ? bio : nil,
                            language: hasLanguageChange ? language : nil,
                            location: hasLocationChange ? location : nil
                        )
                    )
                }
                
                await MainActor.run {
                    isSaving = false
                    hasChanges = false
                    onBack()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to save profile: \(error)")
            }
        }
    }
}


// ================================================================================================
// MARK: - Avatar Selection View
// ================================================================================================

struct AvatarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                SettingsSubViewHeader(title: "Change Avatar", onBack: onBack)
                
                // Current Avatar Preview
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .frame(width: 100, height: 100)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let avatarUrl = rlAppState.currentUser?.avatarUrl,
                                  let url = URL(string: avatarUrl),
                                  !avatarUrl.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Text(String(rlAppState.currentUser?.username.prefix(2) ?? "").uppercased())
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentColor)
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Text(String(rlAppState.currentUser?.username.prefix(2) ?? "").uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        }
                    }
                    
                    Text(selectedImage != nil ? "New Avatar" : "Current Avatar")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                Spacer()
                
                // Upload options
                VStack(spacing: 16) {
                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 24))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose from Library")
                                    .font(.headline)
                                Text("Select a photo from your device")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.greyText)
                        }
                        .foregroundColor(AppColors.whiteText)
                        .padding()
                        .background(AppColors.symbolSheetGroupedPanelFill)
                        .cornerRadius(12)
                    }
                    
                    if selectedImage != nil || rlAppState.currentUser?.avatarUrl != nil {
                        Button(action: removeAvatar) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Remove Avatar")
                                        .font(.headline)
                                    Text("Use default avatar instead")
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.greyText)
                            }
                            .foregroundColor(AppColors.statusNegative)
                            .padding()
                            .background(AppColors.statusNegative10)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 25)
                
                Spacer()
                
                // Save button
                if selectedImage != nil {
                    StandardActionButtonFullWidth(
                        title: "Save Avatar",
                        backgroundColor: AppColors.accentColor,
                        foregroundColor: .white,
                        isLoading: isSaving,
                        isDisabled: isSaving,
                        action: saveAvatar
                    )
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    private func saveAvatar() {
        guard let image = selectedImage else { return }
        isSaving = true
        
        Task {
            do {
                // Compress image to JPEG
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "AvatarError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                
                _ = try await rlAppState.uploadAvatar(imageData: imageData, mimeType: "image/jpeg")
                
                await MainActor.run {
                    isSaving = false
                    onBack()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to upload avatar: \(error)")
            }
        }
    }
    
    private func removeAvatar() {
        Task {
            do {
                _ = try await rlAppState.removeAvatar()
                selectedImage = nil
                onBack()
            } catch {
                print("Failed to remove avatar: \(error)")
            }
        }
    }
}

// Simple image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}


// ================================================================================================
// MARK: - Change Email View
// ================================================================================================

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    @State private var newEmail: String = ""
    @State private var confirmEmail: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    @State private var isSaving = false
    @State private var emailError: String?
    @State private var showSuccessAlert = false
    
    private var isValid: Bool {
        isValidEmail(newEmail) &&
        newEmail == confirmEmail &&
        !password.isEmpty &&
        emailError == nil
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    SettingsSubViewHeader(title: "Change Email", onBack: onBack)
                    
                    VStack(spacing: 24) {
                        // Current email display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.greyText)
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(AppColors.greyText)
                                Text(rlAppState.currentUser?.email ?? "email@example.com")
                                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                                Spacer()
                            }
                            .padding()
                            .background(AppColors.insetPanelBackground)
                            .cornerRadius(12)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // New email fields
                        SettingsTextField(
                            title: "New Email",
                            placeholder: "Enter new email address",
                            text: $newEmail,
                            icon: "envelope.fill",
                            error: emailError,
                            keyboardType: .emailAddress
                        )
                        .onChange(of: newEmail) { _, newValue in
                            validateEmail(newValue)
                        }
                        
                        SettingsTextField(
                            title: "Confirm New Email",
                            placeholder: "Confirm new email address",
                            text: $confirmEmail,
                            icon: "envelope.badge.fill",
                            error: confirmEmail.isEmpty || confirmEmail == newEmail ? nil : "Emails don't match",
                            keyboardType: .emailAddress
                        )
                        
                        // Password verification
                        SettingsSecureField(
                            title: "Current Password",
                            placeholder: "Enter your password to confirm",
                            text: $password,
                            showPassword: $showPassword
                        )
                        
                        // Info box
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.statusInfo)
                            
                            Text("After changing your email, you'll need to verify the new address before it becomes active.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding()
                        .background(AppColors.statusInfo10)
                        .cornerRadius(12)

                        // Save button
                        StandardActionButtonFullWidth(
                            title: "Change Email",
                            backgroundColor: isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                            foregroundColor: .white,
                            isLoading: isSaving,
                            isDisabled: !isValid || isSaving,
                            action: changeEmail
                        )
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
        }
        .alert("Verification Email Sent", isPresented: $showSuccessAlert) {
            Button("OK") { onBack() }
        } message: {
            Text("We've sent a verification link to \(newEmail). Please check your inbox to complete the change.")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = nil
        } else if !isValidEmail(email) {
            emailError = "Please enter a valid email address"
        } else if email.lowercased() == rlAppState.currentUser?.email.lowercased() {
            emailError = "New email must be different from current email"
        } else {
            emailError = nil
        }
    }
    
    private func changeEmail() {
        guard isValid else { return }
        isSaving = true
        
        Task {
            do {
                _ = try await rlAppState.requestEmailChange(newEmail: newEmail, currentPassword: password)
                
                await MainActor.run {
                    isSaving = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to change email: \(error)")
            }
        }
    }
}


// ================================================================================================
// MARK: - Change Password View
// ================================================================================================

struct ChangePasswordView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    private var passwordStrength: PasswordStrength {
        calculatePasswordStrength(newPassword)
    }
    
    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        passwordStrength != .weak
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    SettingsSubViewHeader(title: "Change Password", onBack: onBack)
                    
                    VStack(spacing: 24) {
                        // Current password
                        SettingsSecureField(
                            title: "Current Password",
                            placeholder: "Enter your current password",
                            text: $currentPassword,
                            showPassword: $showCurrentPassword
                        )
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // New password
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsSecureField(
                                title: "New Password",
                                placeholder: "Enter new password",
                                text: $newPassword,
                                showPassword: $showNewPassword
                            )
                            
                            // Password strength indicator
                            if !newPassword.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(0..<4) { index in
                                        Rectangle()
                                            .fill(index < passwordStrength.level ? passwordStrength.color : AppColors.panelFillEmphasis)
                                            .frame(height: 4)
                                            .cornerRadius(2)
                                    }
                                }
                                
                                Text(passwordStrength.text)
                                    .font(.caption)
                                    .foregroundColor(passwordStrength.color)
                            }
                        }
                        
                        // Confirm password
                        SettingsSecureField(
                            title: "Confirm New Password",
                            placeholder: "Confirm new password",
                            text: $confirmPassword,
                            showPassword: $showConfirmPassword,
                            error: confirmPassword.isEmpty || confirmPassword == newPassword ? nil : "Passwords don't match"
                        )
                        
                        // Password requirements
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password Requirements")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.greyText)
                            
                            PasswordRequirementRow(text: "At least 8 characters", isMet: newPassword.count >= 8)
                            PasswordRequirementRow(text: "Contains uppercase letter", isMet: newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil)
                            PasswordRequirementRow(text: "Contains lowercase letter", isMet: newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil)
                            PasswordRequirementRow(text: "Contains number", isMet: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
                            PasswordRequirementRow(text: "Contains special character", isMet: newPassword.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil)
                        }
                        .padding()
                        .background(AppColors.insetPanelBackground)
                        .cornerRadius(12)

                        // Save button
                        StandardActionButtonFullWidth(
                            title: "Update Password",
                            backgroundColor: isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                            foregroundColor: .white,
                            isLoading: isSaving,
                            isDisabled: !isValid || isSaving,
                            action: changePassword
                        )
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
        }
        .alert("Password Updated", isPresented: $showSuccessAlert) {
            Button("OK") { onBack() }
        } message: {
            Text("Your password has been changed successfully.")
        }
    }
    
    private func changePassword() {
        guard isValid else { return }
        isSaving = true
        
        Task {
            do {
                _ = try await rlAppState.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                
                await MainActor.run {
                    isSaving = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to change password: \(error)")
            }
        }
    }
    
    private func calculatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5: return .strong
        default: return .veryStrong
        }
    }
}

enum PasswordStrength {
    case weak, medium, strong, veryStrong
    
    var level: Int {
        switch self {
        case .weak: return 1
        case .medium: return 2
        case .strong: return 3
        case .veryStrong: return 4
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .yellow
        case .veryStrong: return .green
        }
    }
    
    var text: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        case .veryStrong: return "Very Strong"
        }
    }
}

struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isMet ? .green : AppColors.greyText)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? AppColors.whiteText : AppColors.greyText)
        }
    }
}


// ================================================================================================
// MARK: - Date of Birth View
// ================================================================================================

struct DateOfBirthView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void
    
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    private var ageRequirementMet: Bool {
        RLAuthValidator.isAtLeastMinimumSignupAge(selectedDate)
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Date of Birth", onBack: onBack)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Info text
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 50))
                                .foregroundColor(AppColors.accentColor)
                            
                            Text("When were you born?")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("Your date of birth won't be publicly visible and is used to ensure our community guidelines are followed.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        
                        // Date picker
                        DatePicker(
                            "Date of Birth",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.symbolSheetGroupedPanelFill)
                        .cornerRadius(12)
                        
                        // Age warning
                        if !ageRequirementMet {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.statusWarning)
                                
                                Text("You must be at least 13 years old to use Traders Guild.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                            .padding()
                            .background(AppColors.statusWarning10)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 25)
                }
                
                // Save button
                StandardActionButtonFullWidth(
                    title: "Save",
                    backgroundColor: ageRequirementMet ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                    foregroundColor: .white,
                    isLoading: isSaving,
                    isDisabled: !ageRequirementMet || isSaving,
                    action: saveDateOfBirth
                )
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if let dob = rlAppState.currentUser?.dateOfBirth {
                selectedDate = dob
            }
        }
        .alert("Date of Birth Updated", isPresented: $showSuccessAlert) {
            Button("OK") { onBack() }
        } message: {
            Text("Your date of birth has been updated successfully.")
        }
    }
    
    private func saveDateOfBirth() {
        guard ageRequirementMet else { return }
        isSaving = true
        
        Task {
            do {
                _ = try await rlAppState.updateDateOfBirth(selectedDate)
                
                await MainActor.run {
                    isSaving = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to update date of birth: \(error)")
            }
        }
    }
}


// ================================================================================================
// MARK: - Trading Interests View
// ================================================================================================

struct TradingInterestsView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void
    
    @State private var selectedInterests: [RLTradingInterestItem] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    private let availableInterests = RLTradingInterestsCatalog.categories
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                VStack(spacing: 0) {
                    SettingsSubViewHeader(title: "Trading Interests", onBack: onBack)
                    
                    let selectedNames = Set(selectedInterests.map(\.name))
                    ScrollView {
                        VStack(spacing: 24) {
                            // Info text
                            Text("Select your trading interests to help personalize your experience and connect with like-minded traders.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 25)
                                .padding(.top, 10)

                            // Interest categories
                            ForEach(availableInterests, id: \.category) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.category)
                                        .font(.headline)
                                        .foregroundColor(AppColors.whiteText)
                                        .padding(.horizontal, 25)

                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ], spacing: 12) {
                                        ForEach(category.items) { item in
                                            InterestChip(
                                                item: item,
                                                isSelected: selectedNames.contains(item.name),
                                                onTap: {
                                                    toggleInterest(item)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 25)
                                }
                            }
                            
                            // Selected count
                            Text("\(selectedInterests.count) interests selected")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                                .padding(.top, 10)
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.top, 10)
                    }
                    
                    // Save button
                    StandardActionButtonFullWidth(
                        title: "Save Interests",
                        backgroundColor: selectedInterests.isEmpty ? AppColors.greyText.opacity(0.5) : AppColors.accentColor,
                        foregroundColor: .white,
                        isLoading: isSaving,
                        isDisabled: selectedInterests.isEmpty || isSaving,
                        action: saveInterests
                    )
                    .padding(.bottom, 30)
                    .background(
                        LinearGradient(
                            colors: [AppColors.sheetBackground.opacity(0), AppColors.sheetBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                        .offset(y: -50)
                    )
                }
            }
        }
        .task {
            await loadInterests()
        }
        .alert("Interests Updated", isPresented: $showSuccessAlert) {
            Button("OK") { onBack() }
        } message: {
            Text("Your trading interests have been updated successfully.")
        }
    }
    
    private func loadInterests() async {
        isLoading = true
        
        do {
            let profile = try await rlAppState.fetchExtendedProfile()
            selectedInterests = profile.tradingInterests
        } catch {
            print("Failed to load trading interests: \(error)")
        }
        
        isLoading = false
    }
    
    private func toggleInterest(_ item: RLTradingInterestItem) {
        if let index = selectedInterests.firstIndex(where: { $0.name == item.name }) {
            selectedInterests.remove(at: index)
        } else {
            selectedInterests.append(item)
        }
    }
    
    private func saveInterests() {
        isSaving = true
        
        Task {
            do {
                _ = try await rlAppState.updateTradingInterests(selectedInterests)
                
                await MainActor.run {
                    isSaving = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to save trading interests: \(error)")
            }
        }
    }
}

struct InterestChip: View {
    let item: RLTradingInterestItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(isSelected ? AppColors.accentColor : AppColors.whiteText.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? AppColors.accentColor.opacity(0.2) : AppColors.symbolSheetGroupedPanelFill)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accentColor : Color.clear, lineWidth: 1)
            )
        }
    }
}


// ================================================================================================
// MARK: - Blocked Users View
// ================================================================================================

struct BlockedUsersView: View {
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    let onBack: () -> Void
    
    @State private var blockedUsers: [RLBlockedUserDTO] = []
    @State private var showUnblockAlert = false
    @State private var userToUnblock: RLBlockedUserDTO?
    @State private var isLoading = false
    @State private var isUnblocking = false
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Blocked Users", onBack: onBack)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if blockedUsers.isEmpty {
                    // Empty state
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.greyText.opacity(0.5))
                        
                        Text("No Blocked Users")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text("When you block someone, they'll appear here. Blocked users can't send you messages or see your activity.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    // Info text
                    Text("Blocked users can't send you messages, see your profile, or interact with you in any guild.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 25)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    // Blocked users list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(blockedUsers) { user in
                                BlockedUserRow(
                                    user: user,
                                    onUnblock: {
                                        userToUnblock = user
                                        showUnblockAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .task {
            await loadBlockedUsers()
        }
        .alert("Unblock User", isPresented: $showUnblockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .destructive) {
                if let user = userToUnblock {
                    unblockUser(user)
                }
            }
        } message: {
            if let user = userToUnblock {
                Text("Are you sure you want to unblock \(user.username)? They'll be able to send you messages and see your activity again.")
            }
        }
    }
    
    private func loadBlockedUsers() async {
        isLoading = true
        
        do {
            let response = try await rlAppState.fetchBlockedUsers()
            blockedUsers = response.blockedUsers
        } catch {
            print("Failed to load blocked users: \(error)")
        }
        
        isLoading = false
    }
    
    private func unblockUser(_ user: RLBlockedUserDTO) {
        isUnblocking = true
        
        Task {
            do {
                _ = try await rlAppState.unblockUser(membershipId: user.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await leftDrawerViewModel.refreshGuildMembers(
                        guildId: guildId,
                        rlAppState: rlAppState
                    )
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                
                await MainActor.run {
                    withAnimation {
                        blockedUsers.removeAll { $0.id == user.id }
                    }
                    isUnblocking = false
                }
            } catch {
                await MainActor.run {
                    isUnblocking = false
                }
                print("Failed to unblock user: \(error)")
            }
        }
    }
}

struct BlockedUserRow: View {
    let user: RLBlockedUserDTO
    let onUnblock: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            UnifiedMemberAvatar(
                username: user.username,
                avatarURL: user.avatarUrl,
                isOnline: false,
                size: 44,
                showOnlineIndicator: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                
                Text("Blocked \(user.blockedAtFormatted)")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: onUnblock) {
                Text("Unblock")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.statusNegative80)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(AppColors.insetPanelBackground)
        .cornerRadius(12)
    }
}


// ================================================================================================
// MARK: - Data & Privacy View
// ================================================================================================

struct DataPrivacyView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void
    
    @State private var activityVisible = true
    @State private var dmPermissionMode: RLDMPermissionMode = .all
    @State private var dataAnalytics = true
    @State private var personalizedAds = true
    @State private var showClearDataAlert = false
    @State private var isSyncingSettings = false

    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Data & Privacy", onBack: onBack)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Privacy section
                        SettingsSectionHeader(title: "Privacy")

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                icon: "eye.fill",
                                title: "Activity Visible",
                                subtitle: "Let others see what you're currently doing",
                                isOn: $activityVisible,
                                iconColor: .blue
                            )
                            .padding(.horizontal, 16)
                            .onChange(of: activityVisible) { _, newValue in
                                updateUserSettings(activityVisible: newValue)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(AppColors.statusWarning)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Direct Messages")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.whiteText)
                                        Text(dmPermissionMode.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(AppColors.greyText)
                                    }
                                    Spacer()
                                }

                                Picker("Direct Messages", selection: $dmPermissionMode) {
                                    ForEach(RLDMPermissionMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.insetPanelBackground)
                            )
                            .padding(.horizontal, 16)
                            .onChange(of: dmPermissionMode) { _, newValue in
                                updateUserSettings(dmPermissionMode: newValue)
                            }
                        }

                        Divider()
                            .background(AppColors.whiteText.opacity(0.2))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Data section
                        SettingsSectionHeader(title: "Data Usage")

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                icon: "chart.bar.fill",
                                title: "Analytics",
                                subtitle: "Help improve the app by sharing usage data",
                                isOn: $dataAnalytics,
                                iconColor: .green
                            )
                            .padding(.horizontal, 16)
                            .onChange(of: dataAnalytics) { _, newValue in
                                updateUserSettings(analyticsEnabled: newValue)
                            }

                            SettingsToggleRow(
                                icon: "sparkles",
                                title: "Personalized Content",
                                subtitle: "Show content tailored to your interests",
                                isOn: $personalizedAds,
                                iconColor: .purple
                            )
                            .padding(.horizontal, 16)
                            .onChange(of: personalizedAds) { _, newValue in
                                updateUserSettings(personalizedContentEnabled: newValue)
                            }
                        }

                        Divider()
                            .background(AppColors.whiteText.opacity(0.2))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Data management section
                        SettingsSectionHeader(title: "Data Management")

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsButtonRow(
                                icon: "arrow.down.doc.fill",
                                title: "Download My Data",
                                subtitle: "Request a copy of your data",
                                iconColor: .blue
                            ) {
                                requestDataExport()
                            }

                            SettingsButtonRow(
                                icon: "trash.fill",
                                title: "Clear Local Data",
                                subtitle: "Remove cached data from this device",
                                iconColor: .red
                            ) {
                                showClearDataAlert = true
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadUserSettingsIfNeeded()
        }
        .onReceive(rlAppState.$userSettings) { settings in
            if let settings = settings {
                syncSettingsFromState(settings)
            }
        }
        .alert("Clear Local Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                // Clear URL cache
                URLCache.shared.removeAllCachedResponses()
                // Clear tmp directory
                let tmp = FileManager.default.temporaryDirectory
                if let files = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
                    for file in files {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
                // Clear Caches directory
                if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
                   let files = try? FileManager.default.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil) {
                    for file in files {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            }
        } message: {
            Text("This will remove all cached data from this device. Your account data will not be affected.")
        }
    }
    
    private func loadUserSettingsIfNeeded() async {
        if rlAppState.userSettings == nil {
            _ = try? await rlAppState.fetchUserSettings()
        }
    }
    
    private func syncSettingsFromState(_ settings: RLUserSettingsDTO) {
        isSyncingSettings = true
        activityVisible = settings.activityVisible
        dmPermissionMode = settings.dmPermission
        dataAnalytics = settings.analyticsEnabled
        personalizedAds = settings.personalizedContentEnabled
        isSyncingSettings = false
    }
    
    private func updateUserSettings(
        activityVisible: Bool? = nil,
        dmPermissionMode: RLDMPermissionMode? = nil,
        analyticsEnabled: Bool? = nil,
        personalizedContentEnabled: Bool? = nil
    ) {
        guard !isSyncingSettings else { return }
        Task {
            do {
                let request = RLUserSettingsUpdateRequest(
                    showOnlineStatus: nil,
                    allowFriendRequests: nil,
                    activityVisible: activityVisible,
                    analyticsEnabled: analyticsEnabled,
                    personalizedContentEnabled: personalizedContentEnabled,
                    dmPermissionMode: dmPermissionMode?.rawValue
                )
                let updated = try await rlAppState.updateUserSettings(request)
                syncSettingsFromState(updated)
            } catch {
                print("Failed to update user settings: \(error)")
            }
        }
    }
    
    private func requestDataExport() {
        Task {
            do {
                _ = try await rlAppState.requestDataExportForUser()
            } catch {
                print("Failed to request data export: \(error)")
            }
        }
    }
}


// ================================================================================================
// MARK: - Help Center View
// ================================================================================================

struct HelpCenterView: View {
    let onBack: () -> Void
    let onContactSupport: () -> Void
    
    @State private var searchText: String = ""
    @State private var expandedFAQ: String? = nil
    
    private let faqCategories: [(category: String, icon: String, color: Color, faqs: [(question: String, answer: String)])] = [
        ("Getting Started", "play.circle.fill", .green, [
            ("How do I join a guild?", "You can join a guild by searching for guilds in the Discover tab, or by accepting an invitation from an existing member. Open guilds can be joined directly, while closed guilds require approval from an admin."),
            ("What are chart markers?", "Chart markers are annotations you can place on trading charts to share analysis with guild members. You can add entry points, targets, stop losses, and custom notes that other members can see and discuss."),
            ("How does reputation work?", "Reputation is earned through positive contributions to your guild - accurate predictions, helpful analysis, and community engagement. Higher reputation unlocks additional privileges within your guild."),
        ]),
        ("Account & Profile", "person.circle.fill", .blue, [
            ("How do I change my username?", "Go to Settings > Edit Profile to change your username. Usernames must be unique and can only be changed once every 30 days."),
            ("Can I be in multiple guilds?", "Yes! You can join multiple guilds and switch between them using the guild switcher. Your reputation and contributions are tracked separately for each guild."),
            ("How do I delete my account?", "Go to Settings > Account Management > Delete Account. This action is permanent and will remove all your data, markers, and messages from all guilds."),
        ]),
        ("Trading & Charts", "chart.line.uptrend.xyaxis", AppColors.accentColor, [
            ("What markets are supported?", "We support Forex, Stocks, Crypto, Commodities, and Indices. The available symbols depend on your data subscription and guild preferences."),
            ("How do I add a marker to a chart?", "Long-press on any point on the chart to open the marker menu. Select the marker type, add your notes, and tap Save. Your marker will be visible to guild members with chart access."),
            ("Can I import my own chart data?", "Currently, chart data is provided through our market data partners. Custom data import is planned for a future release."),
        ]),
        ("Messaging", "message.fill", .purple, [
            ("Are my messages private?", "Direct messages are private between you and the recipient. Guild chatroom messages are visible to all guild members with chat access."),
            ("Can I delete messages?", "You can delete your own messages within 24 hours of sending them. After that, you can request deletion through Settings > Data & Privacy."),
            ("How do I report a message?", "Long-press on any message and select 'Report'. Our moderation team will review the report and take appropriate action."),
        ]),
    ]
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Help Center", onBack: onBack)
                
                // Search bar
                UnifiedSearchBar(
                    text: $searchText,
                    placeholder: "Search help topics..."
                )
                .padding(.horizontal, 25)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(faqCategories, id: \.category) { category in
                            let filteredFAQs = searchText.isEmpty ? category.faqs : category.faqs.filter {
                                $0.question.localizedCaseInsensitiveContains(searchText) ||
                                $0.answer.localizedCaseInsensitiveContains(searchText)
                            }
                            
                            if !filteredFAQs.isEmpty {
                                FAQCategorySection(
                                    category: category.category,
                                    icon: category.icon,
                                    color: category.color,
                                    faqs: filteredFAQs,
                                    expandedFAQ: $expandedFAQ
                                )
                            }
                        }
                        
                        // Still need help section
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.bubble.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.accentColor)
                            
                            Text("Still need help?")
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("Our support team is here to help you with any questions or issues.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.center)
                            
                            Button(action: onContactSupport) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Contact Support")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.onAccentForeground)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppColors.accentColor)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.insetPanelBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 25)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTapAndDragBackground()
            }
        }
        .dismissKeyboardOnTapAndDragBackground()
    }
}

struct FAQCategorySection: View {
    let category: String
    let icon: String
    let color: Color
    let faqs: [(question: String, answer: String)]
    @Binding var expandedFAQ: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(category)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
            }
            .padding(.horizontal, 25)
            
            VStack(spacing: 8) {
                ForEach(faqs, id: \.question) { faq in
                    FAQItem(
                        question: faq.question,
                        answer: faq.answer,
                        isExpanded: expandedFAQ == faq.question,
                        onTap: {
                            withAnimation {
                                expandedFAQ = expandedFAQ == faq.question ? nil : faq.question
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 25)
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(AppColors.insetPanelBackground)
        .cornerRadius(12)
    }
}


// ================================================================================================
// MARK: - Contact Support View
// ================================================================================================

struct ContactSupportView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void

    @State private var category: String = "general"
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var includeDeviceInfo = true
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: SupportField?

    private enum SupportField {
        case subject, message
    }

    private let categories = [
        SupportCategoryOption(id: "general", title: "General Question", icon: "questionmark.circle.fill", subtitle: "Product questions and how-to help"),
        SupportCategoryOption(id: "bug", title: "Report a Bug", icon: "ant.fill", subtitle: "Technical issues or broken flows"),
        SupportCategoryOption(id: "account", title: "Account Issue", icon: "person.circle.fill", subtitle: "Login, profile, or access problems"),
        SupportCategoryOption(id: "billing", title: "Billing Question", icon: "creditcard.fill", subtitle: "Subscriptions and payment questions"),
        SupportCategoryOption(id: "feedback", title: "Feedback", icon: "star.fill", subtitle: "Ideas and product suggestions"),
        SupportCategoryOption(id: "safety", title: "Safety Concern", icon: "exclamationmark.shield.fill", subtitle: "Harassment, scams, or urgent trust issues")
    ]

    private var selectedCategoryOption: SupportCategoryOption {
        categories.first(where: { $0.id == category }) ?? categories[0]
    }
    
    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        subject.count >= 5 &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty &&
        message.count >= 20
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            KeyboardAwareBottomInsetContainer {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsSubViewHeader(title: "Contact Support", onBack: onBack)

                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(AppColors.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(AppColors.accentColor.opacity(0.16))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("How can we help?")
                                            .font(.headline)
                                            .foregroundColor(AppColors.whiteText)
                                        Text("We typically respond within 24 hours.")
                                            .font(.caption)
                                            .foregroundColor(AppColors.greyText)
                                    }

                                    Spacer()
                                }

                                Text("Choose the closest category, give us a short subject, then include any details that will help us reproduce or understand the issue.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                            .padding(16)
                            .background(AppColors.insetPanelBackground)
                            .cornerRadius(14)
                            .padding(.top, 20)

                            // Category selection
                            SupportCategoryMenuField(
                                title: "Category",
                                selection: $category,
                                options: categories
                            )

                            // Subject
                            SettingsTextField(
                                title: "Subject",
                                placeholder: "Brief description of your issue",
                                text: $subject,
                                icon: "text.alignleft"
                            )
                            .focused($focusedField, equals: .subject)

                            // Message
                            SupportMessageEditorCard(
                                title: "Message",
                                text: $message,
                                placeholder: "Tell us what happened, what you expected, and any steps that reproduce it.",
                                characterLimit: 5000,
                                minHeight: 150
                            )

                            // Error message
                            if let errorMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(errorMessage)
                                        .font(.caption)
                                }
                                .foregroundColor(AppColors.statusNegative70)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.statusNegative08)
                                .cornerRadius(12)
                            }

                            // Device info toggle
                            Toggle(isOn: $includeDeviceInfo) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Include device information")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.whiteText)

                                    Text("Helps us diagnose technical issues")
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                }
                            }
                            .tint(AppColors.accentColor)
                            .padding()
                            .background(AppColors.insetPanelBackground)
                            .cornerRadius(12)

                            HStack(spacing: 10) {
                                Image(systemName: selectedCategoryOption.icon)
                                    .foregroundColor(AppColors.accentColor)
                                Text("Selected: \(selectedCategoryOption.title)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 24)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTapAndDragBackground()
            } footer: {
                VStack(spacing: 0) {
                    Divider()
                    StandardActionButtonFullWidth(
                        title: "Send Message",
                        backgroundColor: isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                        foregroundColor: .white,
                        isLoading: isSending,
                        isDisabled: !isValid || isSending,
                        action: sendTicket
                    )
                    .padding(.horizontal, 25)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .background(AppColors.sheetBackground)
                }
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .alert("Message Sent", isPresented: $showSuccessAlert) {
            Button("OK") { onBack() }
        } message: {
            Text("We've received your message and will get back to you as soon as possible.")
        }
    }
    
    private func sendTicket() {
        guard isValid else { return }
        focusedField = nil
        dismissKeyboard()
        errorMessage = nil
        isSending = true

        Task {
            do {
                _ = try await rlAppState.submitSupportTicket(
                    category: category,
                    subject: subject,
                    message: message,
                    includeDeviceInfo: includeDeviceInfo
                )

                await MainActor.run {
                    isSending = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Failed to send message. Please check your connection and try again."
                }
                print("Failed to send support ticket: \(error)")
            }
        }
    }
}

struct SupportCategoryOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let subtitle: String
}

struct SupportCategoryMenuField: View {
    let title: String
    @Binding var selection: String
    let options: [SupportCategoryOption]

    private var selectedOption: SupportCategoryOption? {
        options.first(where: { $0.id == selection })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        Label(option.title, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedOption?.icon ?? "questionmark.circle.fill")
                        .foregroundColor(AppColors.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedOption?.title ?? "Select category")
                            .foregroundColor(AppColors.whiteText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let subtitle = selectedOption?.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.standardSearchFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                )
            }
        }
    }
}

struct SupportMessageEditorCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let characterLimit: Int
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .padding(12)
                    .background(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                    )
                    .foregroundColor(AppColors.whiteText)
                    .scrollContentBackground(.hidden)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(AppColors.greyText.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Spacer()
                Text("\(text.count)/\(characterLimit)")
                    .font(.caption)
                    .foregroundColor(text.count > characterLimit ? .red : AppColors.greyText)
            }
        }
    }
}


// ================================================================================================
// MARK: - Terms & Privacy View
// ================================================================================================

struct TermsPrivacyView: View {
    let onBack: () -> Void
    let onSelectDocument: (SettingsDestination) -> Void

    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Terms & Privacy", onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsButtonRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            subtitle: "Review our terms and conditions",
                            iconColor: .blue
                        ) {
                            onSelectDocument(.termsOfService)
                        }

                        SettingsButtonRow(
                            icon: "hand.raised.fill",
                            title: "Privacy Policy",
                            subtitle: "Learn how we protect your data",
                            iconColor: .purple
                        ) {
                            onSelectDocument(.privacyPolicy)
                        }

                        SettingsButtonRow(
                            icon: "building.columns.fill",
                            title: "Community Guidelines",
                            subtitle: "Our rules for respectful interaction",
                            iconColor: .green
                        ) {
                            onSelectDocument(.communityGuidelines)
                        }

                        SettingsButtonRow(
                            icon: "gavel.fill",
                            title: "Legal Information",
                            subtitle: "Licenses and legal notices",
                            iconColor: .orange
                        ) {
                            onSelectDocument(.legalInformation)
                        }
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 100)
                }
            }
        }
    }
}


// ================================================================================================
// MARK: - About View
// ================================================================================================

private struct AppIconPreviewView: View {
    var body: some View {
        ZStack {
            if let backgroundImage = bundleImage(named: "appiconbg 2") {
                backgroundImage
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
            }

            if let logoImage = bundleImage(named: "TG 3") {
                logoImage
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            } else {
                Text("TG")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppColors.accentColor)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
        )
        .shadow(color: AppColors.surfaceBlack20, radius: 12, x: 0, y: 6)
    }

    private func bundleImage(named name: String) -> Image? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "AppIconPreview/Assets"
        ) ?? Bundle.main.url(forResource: name, withExtension: "png"),
        let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: image)
    }
}

struct AboutView: View {
    let onBack: () -> Void
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "About", onBack: onBack)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App logo and name
                        VStack(spacing: 16) {
                            AppIconPreviewView()
                            
                            Text("Traders Guild")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding(.top, 32)
                        
                        // Description
                        Text("A collaborative trading platform where traders unite in guilds to share analysis, track performance, and grow together.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        // Risk Disclosure
                        AboutInfoCard(
                            icon: "exclamationmark.shield.fill",
                            title: "Risk Disclosure",
                            message: "Traders Guild is for educational and discussion purposes only. Nothing in this app constitutes financial, investment, or trading advice. Markers, leaderboards, and chat reflect user opinions — not recommendations. Trading involves substantial risk of loss. You are solely responsible for your own decisions."
                        )
                        .padding(.horizontal, 25)

                        // Data Sources
                        AboutInfoCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Data Sources",
                            message: "Crypto market data is sourced from the public Binance API. Prices are provided as-is for informational purposes and may be delayed or interrupted. Traders Guild does not execute trades."
                        )
                        .padding(.horizontal, 25)

                        // Links
                        VStack(spacing: 12) {
                            AboutLinkRow(icon: "globe", title: "Website", subtitle: "tradersguild.co")
                            AboutLinkRow(icon: "envelope.fill", title: "Support", subtitle: "support@tradersguild.co")
                            AboutLinkRow(icon: "bubble.left.and.bubble.right.fill", title: "Twitter", subtitle: "@tradersguild")
                        }
                        .padding(.horizontal, 25)

                        // Copyright
                        Text("© 2026 Traders Guild\nAll rights reserved")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)

                        Spacer(minLength: 100)
                    }
                }
            }
        }
    }
}

struct AboutLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding()
            .background(AppColors.insetPanelBackground)
            .cornerRadius(12)
        }
    }
}

struct AboutInfoCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.accentColor.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)

                Text(message)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.insetPanelBackground)
        .cornerRadius(12)
    }
}


// ================================================================================================
// MARK: - Delete Account Confirmation View
// ================================================================================================

struct DeleteAccountConfirmationView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void
    let onDelete: () -> Void
    
    @State private var currentStep: Int = 1
    @State private var password: String = ""
    @State private var confirmationText: String = ""
    @State private var showPassword = false
    @State private var isDeleting = false

    /// Apple (and other non-password) accounts skip the password step.
    private var requiresPassword: Bool {
        rlAppState.currentUser?.usesEmailPasswordAuth ?? true
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return requiresPassword ? !password.isEmpty : true
        case 2:
            return confirmationText.lowercased() == "delete my account"
        default:
            return false
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    SettingsSubViewHeader(title: "Delete Account", onBack: onBack)
                    
                    VStack(spacing: 32) {
                        // Warning icon and text
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.statusNegative)
                            
                            Text("Delete Your Account?")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("This action cannot be undone. All your data will be permanently deleted.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)

                        if !requiresPassword, currentStep == 2 {
                            Text("Your account uses Sign in with Apple. Confirm below to permanently delete your account — no password is required.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        
                        if currentStep == 1 {
                            // Step 1: Confirm with password
                            VStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("What will be deleted:")
                                        .font(.headline)
                                        .foregroundColor(AppColors.whiteText)
                                    
                                    DeleteItemRow(text: "All your guild memberships")
                                    DeleteItemRow(text: "All your messages and chart markers")
                                    DeleteItemRow(text: "Your profile and reputation")
                                    DeleteItemRow(text: "All your trading statistics")
                                    DeleteItemRow(text: "Your awards and achievements")
                                }
                                .padding()
                                .background(AppColors.statusNegative10)
                                .cornerRadius(12)
                                
                                // Password field
                                SettingsSecureField(
                                    title: "Enter your password to continue",
                                    placeholder: "Password",
                                    text: $password,
                                    showPassword: $showPassword
                                )
                                
                                // Continue button
                                StandardActionButtonFullWidth(
                                    title: "Continue",
                                    backgroundColor: canProceed ? AppColors.statusNegative : AppColors.statusNegative30,
                                    foregroundColor: .white,
                                    isDisabled: !canProceed,
                                    action: { currentStep = 2 }
                                )
                            }
                        } else {
                            // Step 2: Final confirmation
                            VStack(spacing: 24) {
                                // Final warning
                                VStack(spacing: 12) {
                                    Text("⚠️ Final Warning")
                                        .font(.headline)
                                        .foregroundColor(AppColors.statusNegative)
                                    
                                    Text("This will permanently delete your account and all associated data. This action cannot be reversed or undone.")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.greyText)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(AppColors.statusNegative10)
                                .cornerRadius(12)
                                
                                // Confirmation text field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Type \"delete my account\" to confirm")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.greyText)
                                    
                                    TextField("delete my account", text: $confirmationText)
                                        .foregroundColor(AppColors.whiteText)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                
                                // Delete button
                                StandardActionButtonFullWidth(
                                    title: "Delete My Account Permanently",
                                    backgroundColor: canProceed ? AppColors.statusNegative : AppColors.statusNegative30,
                                    foregroundColor: .white,
                                    isLoading: isDeleting,
                                    isDisabled: !canProceed || isDeleting,
                                    action: deleteAccount
                                )
                                
                                Button(action: {
                                    if requiresPassword {
                                        currentStep = 1
                                    } else {
                                        onBack()
                                    }
                                }) {
                                    Text(requiresPassword ? "Go Back" : "Cancel")
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.greyText)
                                }
                            }
                        }
                        
                        // Cancel button
                        StandardActionButtonFullWidth(
                            title: "Cancel",
                            backgroundColor: AppColors.symbolSheetGroupedPanelFill,
                            foregroundColor: AppColors.whiteText,
                            action: onBack
                        )
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 25)
                }
            }
        }
        .onAppear {
            if !requiresPassword {
                currentStep = 2
            }
        }
    }
    
    private func deleteAccount() {
        guard canProceed else { return }
        isDeleting = true
        
        Task {
            do {
                try await rlAppState.deleteAccount(
                    password: requiresPassword ? password : nil,
                    confirmation: confirmationText
                )
                
                await MainActor.run {
                    isDeleting = false
                    onDelete()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                }
                print("Failed to delete account: \(error)")
            }
        }
    }
}

struct DeleteItemRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .font(.caption)
                .foregroundColor(AppColors.statusNegative)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.9))
        }
    }
}


// ================================================================================================
// MARK: - Reusable Components
// ================================================================================================

struct SettingsSubViewHeader: View {
    let title: String
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(AppColors.whiteText)
            }
            
            Spacer()
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
            
            Spacer()
            
            // Invisible button for balance
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                Text("Back")
                    .font(.headline)
            }
            .opacity(0)
        }
        .padding(.horizontal, 25)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

struct SettingsTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var error: String? = nil
    var prefix: String? = nil
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    private var strokeColor: Color {
        if error != nil {
            return AppColors.bearCandleRed.opacity(isFocused ? 0.95 : 0.75)
        }
        return isFocused ? AppColors.whiteText.opacity(0.45) : AppColors.standardSearchFieldStroke
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(error != nil ? .red : AppColors.greyText)
                }

                if let prefix = prefix {
                    Text(prefix)
                        .foregroundColor(AppColors.greyText)
                }

                TextField(placeholder, text: $text)
                    .foregroundColor(AppColors.whiteText)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.standardSearchFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.statusNegative)
            }
        }
    }
}

struct SettingsDropdownField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    let options: [LocaleOption]
    var showsFlags: Bool = false
    var displayValue: (String) -> String = { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            Menu {
                Button("Not specified") {
                    text = ""
                }

                Divider()

                ForEach(options) { option in
                    Button(optionLabel(option)) {
                        text = option.code
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(AppColors.greyText)
                    }

                    Text(text.isEmpty ? placeholder : displayValue(text))
                        .foregroundColor(text.isEmpty ? AppColors.greyText : AppColors.whiteText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.standardSearchFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                )
            }
        }
    }

    private func optionLabel(_ option: LocaleOption) -> String {
        guard showsFlags, let flag = LocaleOptionCatalog.flagEmoji(forCountryCode: option.code) else {
            return option.label
        }
        return "\(flag) \(option.label)"
    }
}

struct SettingsSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var error: String? = nil

    @FocusState private var isFocused: Bool

    private var strokeColor: Color {
        if error != nil {
            return AppColors.bearCandleRed.opacity(isFocused ? 0.95 : 0.75)
        }
        return isFocused ? AppColors.whiteText.opacity(0.45) : AppColors.standardSearchFieldStroke
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(error != nil ? .red : AppColors.greyText)

                if showPassword {
                    TextField(placeholder, text: $text)
                        .foregroundColor(AppColors.whiteText)
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                } else {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(AppColors.whiteText)
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                }

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppColors.greyText)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.standardSearchFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.statusNegative)
            }
        }
    }
}

// NOTE: SettingsSectionHeader, SettingsToggleRow, and SettingsButtonRow
// are defined in MessagingSettings.swift and shared across the app.


// ================================================================================================
// MARK: - Push Notification Settings View
// ================================================================================================

struct PushNotificationSettingsView: View {
    @EnvironmentObject var rlAppState: RLAppState
    let onBack: () -> Void

    @StateObject private var pushManager = PushNotificationManager.shared

    @State private var prefs = RLPushNotificationPreferences()
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                            Text("Back")
                                .font(.headline)
                        }
                        .foregroundColor(AppColors.whiteText)
                    }

                    Spacer()

                    Text("Push Notifications")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.headline)
                        Text("Back").font(.headline)
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .padding(.bottom, 10)

                if pushManager.permissionStatus == .denied {
                    systemSettingsBanner
                }

                if isLoading {
                    ProgressView()
                        .tint(AppColors.primaryForeground)
                        .padding(.top, 40)
                } else {
                    preferencesToggles
                }

                Spacer(minLength: 100)
            }
        }
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .task {
            await loadPreferences()
        }
    }

    // MARK: - System Settings Banner

    private var systemSettingsBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.statusWarning)
                Text("Notifications are disabled at the system level.")
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.insetPanelBackground)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Preference Toggles

    private var preferencesToggles: some View {
        VStack(spacing: 0) {
            // Messages
            SettingsSectionHeader(title: "Messages")

            VStack(spacing: 8) {
                SettingsToggleRow(
                    icon: "envelope.fill",
                    title: "Direct Messages",
                    subtitle: "New DM received (rate-limited)",
                    isOn: $prefs.dm,
                    iconColor: .blue
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.dm) { _, newValue in
                    savePreference(\.dm, value: newValue)
                }

                SettingsToggleRow(
                    icon: "at",
                    title: "Mentions",
                    subtitle: "Someone @mentions you in chat",
                    isOn: $prefs.mention,
                    iconColor: .cyan
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.mention) { _, newValue in
                    savePreference(\.mention, value: newValue)
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Trading
            SettingsSectionHeader(title: "Trading")

            VStack(spacing: 8) {
                SettingsToggleRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Marker Results",
                    subtitle: "Your setup marker hits SL or TP",
                    isOn: $prefs.markerResult,
                    iconColor: .green
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.markerResult) { _, newValue in
                    savePreference(\.markerResult, value: newValue)
                }

                SettingsToggleRow(
                    icon: "heart.fill",
                    title: "Marker Engagement",
                    subtitle: "Milestone likes on your markers (5, 10, 25...)",
                    isOn: $prefs.markerEngagement,
                    iconColor: .pink
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.markerEngagement) { _, newValue in
                    savePreference(\.markerEngagement, value: newValue)
                }

                SettingsToggleRow(
                    icon: "trophy.fill",
                    title: "Awards",
                    subtitle: "You unlock a new award",
                    isOn: $prefs.awards,
                    iconColor: .yellow
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.awards) { _, newValue in
                    savePreference(\.awards, value: newValue)
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Guild
            SettingsSectionHeader(title: "Guild")

            VStack(spacing: 8) {
                SettingsToggleRow(
                    icon: "megaphone.fill",
                    title: "Announcements",
                    subtitle: "New announcement posted in your guild",
                    isOn: $prefs.announcement,
                    iconColor: .orange
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.announcement) { _, newValue in
                    savePreference(\.announcement, value: newValue)
                }

                SettingsToggleRow(
                    icon: "calendar",
                    title: "Events",
                    subtitle: "New event created in your guild",
                    isOn: $prefs.event,
                    iconColor: .purple
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.event) { _, newValue in
                    savePreference(\.event, value: newValue)
                }

                SettingsToggleRow(
                    icon: "calendar.badge.clock",
                    title: "Event Reminder",
                    subtitle: "Reminder before an event you're attending starts",
                    isOn: $prefs.eventReminder,
                    iconColor: .orange
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.eventReminder) { _, newValue in
                    savePreference(\.eventReminder, value: newValue)
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Social
            SettingsSectionHeader(title: "Social")

            VStack(spacing: 8) {
                SettingsToggleRow(
                    icon: "person.badge.plus",
                    title: "Friend Requests",
                    subtitle: "Someone sends you a friend request",
                    isOn: $prefs.friendRequest,
                    iconColor: .green
                )
                .padding(.horizontal, 16)
                .onChange(of: prefs.friendRequest) { _, newValue in
                    savePreference(\.friendRequest, value: newValue)
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Moderation (always on)
            SettingsSectionHeader(title: "Moderation")

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.fill")
                        .foregroundColor(AppColors.statusNegative)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Account Actions")
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        Text("Bans, mutes, kicks and role changes are always delivered")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }

                    Spacer()

                    Text("Always On")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.insetPanelBackground)
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Data Loading

    private func loadPreferences() async {
        await pushManager.refreshPermissionStatus()
        do {
            prefs = try await rlAppState.realApi.getPushPreferences()
        } catch {
            print("⚠️ Failed to load push preferences: \(error.localizedDescription)")
            rlAppState.showError(
                title: RLUserFacingCopy.text(.warningTitle),
                message: RLUserFacingCopy.text(.warningPushPreferencesLoadFailed),
                severity: .warning,
                style: .toast
            )
        }
        isLoading = false
    }

    private func savePreference(_ keyPath: WritableKeyPath<RLPushNotificationPreferences, Bool>, value: Bool) {
        guard !isSaving else { return }
        isSaving = true

        var update = RLPushPreferencesUpdateRequest()
        switch keyPath {
        case \.dm:                update = RLPushPreferencesUpdateRequest(dm: value)
        case \.mention:           update = RLPushPreferencesUpdateRequest(mention: value)
        case \.markerResult:      update = RLPushPreferencesUpdateRequest(markerResult: value)
        case \.markerEngagement:  update = RLPushPreferencesUpdateRequest(markerEngagement: value)
        case \.awards:            update = RLPushPreferencesUpdateRequest(awards: value)
        case \.announcement:      update = RLPushPreferencesUpdateRequest(announcement: value)
        case \.event:             update = RLPushPreferencesUpdateRequest(event: value)
        case \.eventReminder:     update = RLPushPreferencesUpdateRequest(eventReminder: value)
        case \.friendRequest:     update = RLPushPreferencesUpdateRequest(friendRequest: value)
        default: break
        }

        Task {
            defer { isSaving = false }
            do {
                prefs = try await rlAppState.realApi.updatePushPreferences(update)
            } catch {
                print("⚠️ Failed to save push preference: \(error.localizedDescription)")
                rlAppState.showError(
                    title: RLUserFacingCopy.text(.warningTitle),
                    message: RLUserFacingCopy.text(.warningPushPreferencesSaveFailed),
                    severity: .warning,
                    style: .toast
                )
            }
        }
    }
}
