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
    case helpCenter
    case contactSupport
    case rateApp
    case termsPrivacy
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
                                ZStack(alignment: .bottomTrailing) {
                                    UnifiedMemberAvatar(
                                        username: displayName,
                                        avatarURL: rlAppState.currentUser?.avatarUrl,
                                        isOnline: rlAppState.currentUser?.isOnline ?? false,
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
                                                    .foregroundColor(.white)
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
                                    validateDisplayName(newValue)
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
                                    validateUsername(newValue)
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
                                        .background(AppColors.surfaceWhite05)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppColors.surfaceWhite10, lineWidth: 1)
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
                                
                                // Location
                                SettingsTextField(
                                    title: "Language",
                                    placeholder: "Preferred language",
                                    text: $language,
                                    icon: "globe"
                                )
                                .onChange(of: language) { _, _ in
                                    hasChanges = true
                                }

                                // Location
                                SettingsTextField(
                                    title: "Location",
                                    placeholder: "City, Country",
                                    text: $location,
                                    icon: "location.fill"
                                )
                                .onChange(of: location) { _, _ in
                                    hasChanges = true
                                }
                            }
                            .padding(.horizontal, 25)
                            
                            // Save Button
                            Button(action: saveProfile) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Save Changes")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isValid && hasChanges ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isValid || !hasChanges || isSaving)
                            .padding(.horizontal, 25)
                            .padding(.top, 10)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
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
            language = profile.language ?? ""
            location = profile.location ?? ""
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
                let hasLanguageChange = language != (extendedProfile?.language ?? "")
                let hasLocationChange = location != (extendedProfile?.location ?? "")
                
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
                        .background(AppColors.surfaceWhite05)
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
                            .foregroundColor(.red)
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
                    Button(action: saveAvatar) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Save Avatar")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 25)
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
                try await rlAppState.removeAvatar()
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
                            .background(AppColors.surfaceWhite03)
                            .cornerRadius(10)
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
                                .foregroundColor(.blue)
                            
                            Text("After changing your email, you'll need to verify the new address before it becomes active.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding()
                        .background(AppColors.statusInfo10)
                        .cornerRadius(10)
                        
                        // Save button
                        Button(action: changeEmail) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Change Email")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isSaving)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 100)
                }
            }
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
                try await rlAppState.requestEmailChange(newEmail: newEmail, currentPassword: password)
                
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
                                            .fill(index < passwordStrength.level ? passwordStrength.color : AppColors.surfaceWhite10)
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
                        .background(AppColors.surfaceWhite03)
                        .cornerRadius(10)
                        
                        // Save button
                        Button(action: changePassword) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Update Password")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isSaving)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 100)
                }
            }
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
                try await rlAppState.changePassword(
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
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: selectedDate, to: now)
        return (ageComponents.year ?? 0) >= 13
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
                        .background(AppColors.surfaceWhite05)
                        .cornerRadius(12)
                        
                        // Age warning
                        if !ageRequirementMet {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                Text("You must be at least 13 years old to use Traders Guild.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                            .padding()
                            .background(AppColors.statusWarning10)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 25)
                }
                
                // Save button
                VStack {
                    Button(action: saveDateOfBirth) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ageRequirementMet ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!ageRequirementMet || isSaving)
                }
                .padding(.horizontal, 25)
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
                try await rlAppState.updateDateOfBirth(selectedDate)
                
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
                                                isSelected: selectedInterests.contains(where: { $0.name == item.name }),
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
                    VStack {
                        Button(action: saveInterests) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Save Interests")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedInterests.isEmpty ? AppColors.greyText.opacity(0.5) : AppColors.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(selectedInterests.isEmpty || isSaving)
                        .padding(.horizontal, 25)
                        .padding(.bottom, 30)
                    }
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
            .background(isSelected ? AppColors.accentColor.opacity(0.2) : AppColors.surfaceWhite05)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
                try await rlAppState.unblockUser(membershipId: user.membershipId)
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.statusNegative80)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(AppColors.surfaceWhite03)
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
                                        .foregroundColor(.orange)
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
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.surfaceWhite03)
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
            try? await rlAppState.fetchUserSettings()
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
                try await rlAppState.requestDataExportForUser()
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
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.greyText)
                    
                    TextField("Search help topics...", text: $searchText)
                        .foregroundColor(AppColors.whiteText)
                }
                .padding()
                .background(AppColors.surfaceWhite05)
                .cornerRadius(12)
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
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Contact Support")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppColors.accentColor)
                                .cornerRadius(10)
                            }
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.surfaceWhite03)
                        .cornerRadius(16)
                        .padding(.horizontal, 25)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
        }
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
        .background(AppColors.surfaceWhite03)
        .cornerRadius(10)
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
        ("general", "General Question", "questionmark.circle.fill"),
        ("bug", "Report a Bug", "ant.fill"),
        ("account", "Account Issue", "person.circle.fill"),
        ("billing", "Billing Question", "creditcard.fill"),
        ("feedback", "Feedback", "star.fill"),
        ("safety", "Safety Concern", "exclamationmark.shield.fill")
    ]
    
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
            
            ScrollView {
                VStack(spacing: 0) {
                    SettingsSubViewHeader(title: "Contact Support", onBack: onBack)

                    VStack(spacing: 24) {
                        // Info text
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.accentColor)

                            Text("How can we help?")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)

                            Text("We typically respond within 24 hours")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding(.top, 20)

                        // Category selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.greyText)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(categories, id: \.0) { cat in
                                    CategoryChip(
                                        id: cat.0,
                                        name: cat.1,
                                        icon: cat.2,
                                        isSelected: category == cat.0,
                                        onTap: { category = cat.0 }
                                    )
                                }
                            }
                        }

                        // Subject
                        SettingsTextField(
                            title: "Subject",
                            placeholder: "Brief description of your issue",
                            text: $subject,
                            icon: "text.alignleft"
                        )
                        .focused($focusedField, equals: .subject)

                        // Message
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.greyText)

                            TextEditor(text: $message)
                                .frame(minHeight: 150)
                                .padding(12)
                                .background(AppColors.surfaceWhite05)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.surfaceWhite10, lineWidth: 1)
                                )
                                .foregroundColor(AppColors.whiteText)
                                .focused($focusedField, equals: .message)

                            HStack {
                                Spacer()
                                Text("\(message.count)/5000")
                                    .font(.caption)
                                    .foregroundColor(message.count > 5000 ? .red : AppColors.greyText)
                            }
                        }

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
                            .cornerRadius(8)
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
                        .background(AppColors.surfaceWhite03)
                        .cornerRadius(10)

                        // Send button
                        Button(action: sendTicket) {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Send Message")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || isSending)
                    }
                    .padding(.horizontal, 25)

                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(AppColors.accentColor)
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
        errorMessage = nil
        isSending = true

        Task {
            do {
                try await rlAppState.submitSupportTicket(
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

struct CategoryChip: View {
    let id: String
    let name: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(isSelected ? AppColors.accentColor : AppColors.whiteText.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? AppColors.accentColor.opacity(0.2) : AppColors.surfaceWhite05)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}


// ================================================================================================
// MARK: - Terms & Privacy View
// ================================================================================================

struct TermsPrivacyView: View {
    @Environment(\.openURL) private var openURL
    let onBack: () -> Void

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
                            if let url = URL(string: "https://tradersguild.co/terms") {
                                openURL(url)
                            }
                        }

                        SettingsButtonRow(
                            icon: "hand.raised.fill",
                            title: "Privacy Policy",
                            subtitle: "Learn how we protect your data",
                            iconColor: .purple
                        ) {
                            if let url = URL(string: "https://tradersguild.co/privacy") {
                                openURL(url)
                            }
                        }

                        SettingsButtonRow(
                            icon: "building.columns.fill",
                            title: "Community Guidelines",
                            subtitle: "Our rules for respectful interaction",
                            iconColor: .green
                        ) {
                            if let url = URL(string: "https://tradersguild.co/guidelines") {
                                openURL(url)
                            }
                        }

                        SettingsButtonRow(
                            icon: "gavel.fill",
                            title: "Legal Information",
                            subtitle: "Licenses and legal notices",
                            iconColor: .orange
                        ) {
                            if let url = URL(string: "https://tradersguild.co/legal") {
                                openURL(url)
                            }
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
                            Circle()
                                .fill(AppColors.accentColor.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("TG")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(AppColors.accentColor)
                                )
                            
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
                        
                        // Links
                        VStack(spacing: 12) {
                            AboutLinkRow(icon: "globe", title: "Website", subtitle: "traders.guild")
                            AboutLinkRow(icon: "envelope.fill", title: "Support", subtitle: "support@traders.guild")
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
            .background(AppColors.surfaceWhite03)
            .cornerRadius(12)
        }
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
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !password.isEmpty
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
                                .foregroundColor(.red)
                            
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
                                Button(action: { currentStep = 2 }) {
                                    Text("Continue")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(canProceed ? AppColors.statusNegative : AppColors.statusNegative30)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(!canProceed)
                            }
                        } else {
                            // Step 2: Final confirmation
                            VStack(spacing: 24) {
                                // Final warning
                                VStack(spacing: 12) {
                                    Text("⚠️ Final Warning")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
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
                                        .background(AppColors.surfaceWhite05)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppColors.surfaceWhite10, lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                
                                // Delete button
                                Button(action: deleteAccount) {
                                    HStack {
                                        if isDeleting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Delete My Account Permanently")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(canProceed ? AppColors.statusNegative : AppColors.statusNegative30)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(!canProceed || isDeleting)
                                
                                Button(action: { currentStep = 1 }) {
                                    Text("Go Back")
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.greyText)
                                }
                            }
                        }
                        
                        // Cancel button
                        Button(action: onBack) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.surfaceWhite05)
                                .foregroundColor(AppColors.whiteText)
                                .cornerRadius(12)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 25)
                }
            }
        }
    }
    
    private func deleteAccount() {
        guard canProceed else { return }
        isDeleting = true
        
        Task {
            do {
                try await rlAppState.deleteAccount(password: password, confirmation: confirmationText)
                
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
                .foregroundColor(.red)
            
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
            }
            .padding()
            .background(AppColors.surfaceWhite05)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error != nil ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
            )
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct SettingsSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var error: String? = nil
    
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
                } else {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(AppColors.whiteText)
                        .textInputAutocapitalization(.never)
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppColors.greyText)
                }
            }
            .padding()
            .background(AppColors.surfaceWhite05)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error != nil ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
            )
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// NOTE: SettingsSectionHeader, SettingsToggleRow, and SettingsButtonRow
// are defined in MessagingSettings.swift and shared across the app.











// //
// //  UserSettingsSubViews.swift
// //  traders_guild
// //
// //  Comprehensive settings subviews for profile editing, account management,
// //  help & support, blocked users, trading interests, and more.
// //
// //  Created by Al Hennessey on 29/01/2026.
// //

// import SwiftUI


// // ================================================================================================
// // MARK: - Navigation State for Settings
// // ================================================================================================

// /// Centralized navigation state for settings flow
// enum SettingsDestination: Hashable {
//     case editProfile
//     case avatarSelection
//     case changeEmail
//     case changePassword
//     case dateOfBirth
//     case tradingInterests
//     case blockedUsers
//     case dataPrivacy
//     case helpCenter
//     case contactSupport
//     case rateApp
//     case termsPrivacy
//     case about
//     case leaveGuild
//     case deleteAccount
// }


// // ================================================================================================
// // MARK: - Edit Profile View
// // ================================================================================================

// struct EditProfileView: View {
//     @Environment(\.dismiss) private var dismiss
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
    
//     // Form state
//     @State private var displayName: String = ""
//     @State private var username: String = ""
//     @State private var bio: String = ""
//     @State private var isLoading = false
//     @State private var isSaving = false
//     @State private var showAvatarPicker = false
//     @State private var showDiscardAlert = false
//     @State private var hasChanges = false
    
//     // Validation
//     @State private var usernameError: String?
//     @State private var displayNameError: String?
    
//     private var isValid: Bool {
//         !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
//         !username.trimmingCharacters(in: .whitespaces).isEmpty &&
//         usernameError == nil &&
//         displayNameError == nil
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             ScrollView {
//                 VStack(spacing: 0) {
//                     // Header
//                     SettingsSubViewHeader(
//                         title: "Edit Profile",
//                         onBack: {
//                             if hasChanges {
//                                 showDiscardAlert = true
//                             } else {
//                                 onBack()
//                             }
//                         }
//                     )
                    
//                     VStack(spacing: 24) {
//                         // Avatar Section
//                         VStack(spacing: 12) {
//                             ZStack(alignment: .bottomTrailing) {
//                                 Circle()
//                                     .fill(AppColors.accentColor.opacity(0.3))
//                                     .frame(width: 100, height: 100)
//                                     .overlay(
//                                         Text(String(displayName.prefix(2)).uppercased())
//                                             .font(.title)
//                                             .fontWeight(.bold)
//                                             .foregroundColor(AppColors.accentColor)
//                                     )
                                
//                                 Button(action: { showAvatarPicker = true }) {
//                                     Circle()
//                                         .fill(AppColors.accentColor)
//                                         .frame(width: 32, height: 32)
//                                         .overlay(
//                                             Image(systemName: "camera.fill")
//                                                 .font(.system(size: 14))
//                                                 .foregroundColor(.white)
//                                         )
//                                 }
//                             }
                            
//                             Button(action: { showAvatarPicker = true }) {
//                                 Text("Change Avatar")
//                                     .font(.subheadline)
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.accentColor)
//                             }
//                         }
//                         .padding(.top, 20)
                        
//                         // Form Fields
//                         VStack(spacing: 20) {
//                             // Display Name
//                             SettingsTextField(
//                                 title: "Display Name",
//                                 placeholder: "Your display name",
//                                 text: $displayName,
//                                 icon: "person.fill",
//                                 error: displayNameError
//                             )
//                             .onChange(of: displayName) { _, newValue in
//                                 hasChanges = true
//                                 validateDisplayName(newValue)
//                             }
                            
//                             // Username
//                             SettingsTextField(
//                                 title: "Username",
//                                 placeholder: "username",
//                                 text: $username,
//                                 icon: "at",
//                                 error: usernameError,
//                                 prefix: "@"
//                             )
//                             .onChange(of: username) { _, newValue in
//                                 hasChanges = true
//                                 validateUsername(newValue)
//                             }
                            
//                             // Bio
//                             VStack(alignment: .leading, spacing: 8) {
//                                 Text("Bio")
//                                     .font(.subheadline)
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.greyText)
                                
//                                 TextEditor(text: $bio)
//                                     .frame(minHeight: 100)
//                                     .padding(12)
//                                     .background(AppColors.surfaceWhite05)
//                                     .cornerRadius(10)
//                                     .overlay(
//                                         RoundedRectangle(cornerRadius: 10)
//                                             .stroke(AppColors.surfaceWhite10, lineWidth: 1)
//                                     )
//                                     .foregroundColor(AppColors.whiteText)
//                                     .onChange(of: bio) { _, _ in
//                                         hasChanges = true
//                                     }
                                
//                                 HStack {
//                                     Spacer()
//                                     Text("\(bio.count)/200")
//                                         .font(.caption)
//                                         .foregroundColor(bio.count > 200 ? .red : AppColors.greyText)
//                                 }
//                             }
//                         }
//                         .padding(.horizontal, 25)
                        
//                         // Save Button
//                         Button(action: saveProfile) {
//                             HStack {
//                                 if isSaving {
//                                     ProgressView()
//                                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                         .scaleEffect(0.8)
//                                 } else {
//                                     Text("Save Changes")
//                                         .fontWeight(.semibold)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity)
//                             .padding(.vertical, 14)
//                             .background(isValid && hasChanges ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                             .foregroundColor(.white)
//                             .cornerRadius(12)
//                         }
//                         .disabled(!isValid || !hasChanges || isSaving)
//                         .padding(.horizontal, 25)
//                         .padding(.top, 10)
//                     }
                    
//                     Spacer(minLength: 100)
//                 }
//             }
//         }
//         .onAppear {
//             loadCurrentProfile()
//         }
//         .sheet(isPresented: $showAvatarPicker) {
//             AvatarSelectionView(onBack: { showAvatarPicker = false })
//                 .environmentObject(rlAppState)
//         }
//         .alert("Discard Changes?", isPresented: $showDiscardAlert) {
//             Button("Keep Editing", role: .cancel) { }
//             Button("Discard", role: .destructive) { onBack() }
//         } message: {
//             Text("You have unsaved changes. Are you sure you want to discard them?")
//         }
//     }
    
//     // MARK: - Functions
    
//     private func loadCurrentProfile() {
//         if let user = rlAppState.currentUser {
//             displayName = user.displayName
//             username = user.username
//             // bio would come from extended profile
//         }
//     }
    
//     private func validateDisplayName(_ name: String) {
//         if name.trimmingCharacters(in: .whitespaces).isEmpty {
//             displayNameError = "Display name is required"
//         } else if name.count < 2 {
//             displayNameError = "Display name must be at least 2 characters"
//         } else if name.count > 50 {
//             displayNameError = "Display name must be less than 50 characters"
//         } else {
//             displayNameError = nil
//         }
//     }
    
//     private func validateUsername(_ name: String) {
//         let trimmed = name.trimmingCharacters(in: .whitespaces)
//         if trimmed.isEmpty {
//             usernameError = "Username is required"
//         } else if trimmed.count < 3 {
//             usernameError = "Username must be at least 3 characters"
//         } else if trimmed.count > 20 {
//             usernameError = "Username must be less than 20 characters"
//         } else if !trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
//             usernameError = "Username can only contain letters, numbers, and underscores"
//         } else {
//             usernameError = nil
//         }
//     }
    
//     private func saveProfile() {
//         guard isValid else { return }
//         isSaving = true
        
//         // Simulate API call
//         Task {
//             try? await Task.sleep(nanoseconds: 1_500_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 hasChanges = false
//                 onBack()
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Avatar Selection View
// // ================================================================================================

// struct AvatarSelectionView: View {
//     @Environment(\.dismiss) private var dismiss
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
    
//     @State private var selectedCategory: AvatarCategory = .default
//     @State private var selectedAvatarId: String? = nil
//     @State private var showingImagePicker = false
//     @State private var isSaving = false
    
//     enum AvatarCategory: String, CaseIterable {
//         case `default` = "Default"
//         case animals = "Animals"
//         case abstract = "Abstract"
//         case trading = "Trading"
//         case custom = "Custom"
        
//         var icon: String {
//             switch self {
//             case .default: return "person.circle"
//             case .animals: return "hare.fill"
//             case .abstract: return "circle.hexagongrid.fill"
//             case .trading: return "chart.line.uptrend.xyaxis"
//             case .custom: return "photo.fill"
//             }
//         }
//     }
    
//     // Sample avatar data
//     private let defaultAvatars = [
//         ("avatar_1", "😊"), ("avatar_2", "🎯"), ("avatar_3", "⚡️"),
//         ("avatar_4", "🔥"), ("avatar_5", "💎"), ("avatar_6", "🚀")
//     ]
    
//     private let animalAvatars = [
//         ("animal_1", "🦁"), ("animal_2", "🐺"), ("animal_3", "🦊"),
//         ("animal_4", "🐻"), ("animal_5", "🦅"), ("animal_6", "🐯")
//     ]
    
//     private let abstractAvatars = [
//         ("abstract_1", "🔷"), ("abstract_2", "🟣"), ("abstract_3", "🔶"),
//         ("abstract_4", "⬛️"), ("abstract_5", "🔵"), ("abstract_6", "🟢")
//     ]
    
//     private let tradingAvatars = [
//         ("trading_1", "📈"), ("trading_2", "💰"), ("trading_3", "📊"),
//         ("trading_4", "🏦"), ("trading_5", "💵"), ("trading_6", "🎰")
//     ]
    
//     private var currentAvatars: [(String, String)] {
//         switch selectedCategory {
//         case .default: return defaultAvatars
//         case .animals: return animalAvatars
//         case .abstract: return abstractAvatars
//         case .trading: return tradingAvatars
//         case .custom: return []
//         }
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 // Header
//                 SettingsSubViewHeader(title: "Choose Avatar", onBack: onBack)
                
//                 // Current Avatar Preview
//                 VStack(spacing: 12) {
//                     ZStack {
//                         Circle()
//                             .fill(AppColors.accentColor.opacity(0.3))
//                             .frame(width: 100, height: 100)
                        
//                         if let avatarId = selectedAvatarId,
//                            let avatar = (defaultAvatars + animalAvatars + abstractAvatars + tradingAvatars).first(where: { $0.0 == avatarId }) {
//                             Text(avatar.1)
//                                 .font(.system(size: 50))
//                         } else {
//                             Text(String(rlAppState.currentUser?.displayName.prefix(2) ?? "").uppercased())
//                                 .font(.title)
//                                 .fontWeight(.bold)
//                                 .foregroundColor(AppColors.accentColor)
//                         }
//                     }
                    
//                     Text("Preview")
//                         .font(.caption)
//                         .foregroundColor(AppColors.greyText)
//                 }
//                 .padding(.top, 20)
//                 .padding(.bottom, 24)
                
//                 // Category Picker
//                 ScrollView(.horizontal, showsIndicators: false) {
//                     HStack(spacing: 12) {
//                         ForEach(AvatarCategory.allCases, id: \.self) { category in
//                             Button(action: { selectedCategory = category }) {
//                                 VStack(spacing: 6) {
//                                     Image(systemName: category.icon)
//                                         .font(.system(size: 20))
//                                     Text(category.rawValue)
//                                         .font(.caption)
//                                 }
//                                 .foregroundColor(selectedCategory == category ? AppColors.accentColor : AppColors.greyText)
//                                 .padding(.horizontal, 16)
//                                 .padding(.vertical, 10)
//                                 .background(
//                                     RoundedRectangle(cornerRadius: 10)
//                                         .fill(selectedCategory == category ? AppColors.accentColor.opacity(0.2) : AppColors.surfaceWhite05)
//                                 )
//                                 .overlay(
//                                     RoundedRectangle(cornerRadius: 10)
//                                         .stroke(selectedCategory == category ? AppColors.accentColor : Color.clear, lineWidth: 1)
//                                 )
//                             }
//                         }
//                     }
//                     .padding(.horizontal, 25)
//                 }
                
//                 // Avatar Grid or Custom Upload
//                 if selectedCategory == .custom {
//                     // Custom upload section
//                     VStack(spacing: 20) {
//                         Spacer()
                        
//                         Button(action: { showingImagePicker = true }) {
//                             VStack(spacing: 16) {
//                                 ZStack {
//                                     RoundedRectangle(cornerRadius: 16)
//                                         .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
//                                         .foregroundColor(AppColors.greyText.opacity(0.5))
//                                         .frame(width: 150, height: 150)
                                    
//                                     VStack(spacing: 8) {
//                                         Image(systemName: "photo.badge.plus")
//                                             .font(.system(size: 40))
//                                             .foregroundColor(AppColors.accentColor)
//                                         Text("Upload Photo")
//                                             .font(.subheadline)
//                                             .foregroundColor(AppColors.greyText)
//                                     }
//                                 }
//                             }
//                         }
                        
//                         Text("Upload a custom photo from your device.\nRecommended: Square image, at least 200x200px")
//                             .font(.caption)
//                             .foregroundColor(AppColors.greyText)
//                             .multilineTextAlignment(.center)
                        
//                         Spacer()
//                     }
//                     .padding(.top, 30)
//                 } else {
//                     // Avatar grid
//                     ScrollView {
//                         LazyVGrid(columns: [
//                             GridItem(.flexible(), spacing: 16),
//                             GridItem(.flexible(), spacing: 16),
//                             GridItem(.flexible(), spacing: 16)
//                         ], spacing: 16) {
//                             ForEach(currentAvatars, id: \.0) { avatar in
//                                 Button(action: { selectedAvatarId = avatar.0 }) {
//                                     ZStack {
//                                         Circle()
//                                             .fill(selectedAvatarId == avatar.0 ?
//                                                   AppColors.accentColor.opacity(0.3) :
//                                                     AppColors.surfaceWhite05)
//                                             .frame(width: 80, height: 80)
                                        
//                                         Text(avatar.1)
//                                             .font(.system(size: 36))
                                        
//                                         if selectedAvatarId == avatar.0 {
//                                             Circle()
//                                                 .stroke(AppColors.accentColor, lineWidth: 3)
//                                                 .frame(width: 80, height: 80)
                                            
//                                             Image(systemName: "checkmark.circle.fill")
//                                                 .font(.system(size: 20))
//                                                 .foregroundColor(AppColors.accentColor)
//                                                 .background(Circle().fill(AppColors.sheetBackground))
//                                                 .offset(x: 28, y: 28)
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//                         .padding(.horizontal, 25)
//                         .padding(.top, 24)
//                     }
//                 }
                
//                 Spacer()
                
//                 // Save Button
//                 Button(action: saveAvatar) {
//                     HStack {
//                         if isSaving {
//                             ProgressView()
//                                 .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                 .scaleEffect(0.8)
//                         } else {
//                             Text("Save Avatar")
//                                 .fontWeight(.semibold)
//                         }
//                     }
//                     .frame(maxWidth: .infinity)
//                     .padding(.vertical, 14)
//                     .background(selectedAvatarId != nil ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                     .foregroundColor(.white)
//                     .cornerRadius(12)
//                 }
//                 .disabled(selectedAvatarId == nil || isSaving)
//                 .padding(.horizontal, 25)
//                 .padding(.bottom, 30)
//             }
//         }
//     }
    
//     private func saveAvatar() {
//         guard selectedAvatarId != nil else { return }
//         isSaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_000_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 onBack()
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Change Email View
// // ================================================================================================

// struct ChangeEmailView: View {
//     @Environment(\.dismiss) private var dismiss
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
    
//     @State private var newEmail: String = ""
//     @State private var confirmEmail: String = ""
//     @State private var password: String = ""
//     @State private var showPassword = false
//     @State private var isSaving = false
//     @State private var emailError: String?
//     @State private var showSuccessAlert = false
    
//     private var isValid: Bool {
//         isValidEmail(newEmail) &&
//         newEmail == confirmEmail &&
//         !password.isEmpty &&
//         emailError == nil
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             ScrollView {
//                 VStack(spacing: 0) {
//                     SettingsSubViewHeader(title: "Change Email", onBack: onBack)
                    
//                     VStack(spacing: 24) {
//                         // Current email display
//                         VStack(alignment: .leading, spacing: 8) {
//                             Text("Current Email")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             HStack {
//                                 Image(systemName: "envelope.fill")
//                                     .foregroundColor(AppColors.greyText)
//                                 Text(rlAppState.currentUser?.email ?? "email@example.com")
//                                     .foregroundColor(AppColors.whiteText.opacity(0.7))
//                                 Spacer()
//                             }
//                             .padding()
//                             .background(AppColors.surfaceWhite03)
//                             .cornerRadius(10)
//                         }
                        
//                         Divider()
//                             .padding(.vertical, 8)
                        
//                         // New email fields
//                         SettingsTextField(
//                             title: "New Email",
//                             placeholder: "Enter new email address",
//                             text: $newEmail,
//                             icon: "envelope.fill",
//                             error: emailError,
//                             keyboardType: .emailAddress
//                         )
//                         .onChange(of: newEmail) { _, newValue in
//                             validateEmail(newValue)
//                         }
                        
//                         SettingsTextField(
//                             title: "Confirm New Email",
//                             placeholder: "Confirm new email address",
//                             text: $confirmEmail,
//                             icon: "envelope.badge.fill",
//                             error: confirmEmail.isEmpty || confirmEmail == newEmail ? nil : "Emails don't match",
//                             keyboardType: .emailAddress
//                         )
                        
//                         // Password verification
//                         SettingsSecureField(
//                             title: "Current Password",
//                             placeholder: "Enter your password to confirm",
//                             text: $password,
//                             showPassword: $showPassword
//                         )
                        
//                         // Info box
//                         HStack(alignment: .top, spacing: 12) {
//                             Image(systemName: "info.circle.fill")
//                                 .foregroundColor(.blue)
                            
//                             Text("After changing your email, you'll need to verify the new address before it becomes active.")
//                                 .font(.caption)
//                                 .foregroundColor(AppColors.greyText)
//                         }
//                         .padding()
//                         .background(AppColors.statusInfo10)
//                         .cornerRadius(10)
                        
//                         // Save button
//                         Button(action: changeEmail) {
//                             HStack {
//                                 if isSaving {
//                                     ProgressView()
//                                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                         .scaleEffect(0.8)
//                                 } else {
//                                     Text("Change Email")
//                                         .fontWeight(.semibold)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity)
//                             .padding(.vertical, 14)
//                             .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                             .foregroundColor(.white)
//                             .cornerRadius(12)
//                         }
//                         .disabled(!isValid || isSaving)
//                     }
//                     .padding(.horizontal, 25)
//                     .padding(.top, 20)
                    
//                     Spacer(minLength: 100)
//                 }
//             }
//         }
//         .alert("Verification Email Sent", isPresented: $showSuccessAlert) {
//             Button("OK") { onBack() }
//         } message: {
//             Text("We've sent a verification link to \(newEmail). Please check your inbox to complete the change.")
//         }
//     }
    
//     private func isValidEmail(_ email: String) -> Bool {
//         let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
//         return email.range(of: emailRegex, options: .regularExpression) != nil
//     }
    
//     private func validateEmail(_ email: String) {
//         if email.isEmpty {
//             emailError = nil
//         } else if !isValidEmail(email) {
//             emailError = "Please enter a valid email address"
//         } else if email.lowercased() == rlAppState.currentUser?.email.lowercased() {
//             emailError = "New email must be different from current email"
//         } else {
//             emailError = nil
//         }
//     }
    
//     private func changeEmail() {
//         guard isValid else { return }
//         isSaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_500_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 showSuccessAlert = true
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Change Password View
// // ================================================================================================

// struct ChangePasswordView: View {
//     let onBack: () -> Void
    
//     @State private var currentPassword: String = ""
//     @State private var newPassword: String = ""
//     @State private var confirmPassword: String = ""
//     @State private var showCurrentPassword = false
//     @State private var showNewPassword = false
//     @State private var showConfirmPassword = false
//     @State private var isSaving = false
//     @State private var showSuccessAlert = false
    
//     private var passwordStrength: PasswordStrength {
//         calculatePasswordStrength(newPassword)
//     }
    
//     private var isValid: Bool {
//         !currentPassword.isEmpty &&
//         newPassword.count >= 8 &&
//         newPassword == confirmPassword &&
//         passwordStrength != .weak
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             ScrollView {
//                 VStack(spacing: 0) {
//                     SettingsSubViewHeader(title: "Change Password", onBack: onBack)
                    
//                     VStack(spacing: 24) {
//                         // Current password
//                         SettingsSecureField(
//                             title: "Current Password",
//                             placeholder: "Enter your current password",
//                             text: $currentPassword,
//                             showPassword: $showCurrentPassword
//                         )
                        
//                         Divider()
//                             .padding(.vertical, 8)
                        
//                         // New password
//                         VStack(alignment: .leading, spacing: 8) {
//                             SettingsSecureField(
//                                 title: "New Password",
//                                 placeholder: "Enter new password",
//                                 text: $newPassword,
//                                 showPassword: $showNewPassword
//                             )
                            
//                             // Password strength indicator
//                             if !newPassword.isEmpty {
//                                 HStack(spacing: 4) {
//                                     ForEach(0..<4) { index in
//                                         Rectangle()
//                                             .fill(index < passwordStrength.level ? passwordStrength.color : AppColors.surfaceWhite10)
//                                             .frame(height: 4)
//                                             .cornerRadius(2)
//                                     }
//                                 }
                                
//                                 Text(passwordStrength.text)
//                                     .font(.caption)
//                                     .foregroundColor(passwordStrength.color)
//                             }
//                         }
                        
//                         // Confirm password
//                         SettingsSecureField(
//                             title: "Confirm New Password",
//                             placeholder: "Confirm new password",
//                             text: $confirmPassword,
//                             showPassword: $showConfirmPassword,
//                             error: confirmPassword.isEmpty || confirmPassword == newPassword ? nil : "Passwords don't match"
//                         )
                        
//                         // Password requirements
//                         VStack(alignment: .leading, spacing: 8) {
//                             Text("Password Requirements")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             PasswordRequirementRow(text: "At least 8 characters", isMet: newPassword.count >= 8)
//                             PasswordRequirementRow(text: "Contains uppercase letter", isMet: newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil)
//                             PasswordRequirementRow(text: "Contains lowercase letter", isMet: newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil)
//                             PasswordRequirementRow(text: "Contains number", isMet: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
//                             PasswordRequirementRow(text: "Contains special character", isMet: newPassword.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil)
//                         }
//                         .padding()
//                         .background(AppColors.surfaceWhite03)
//                         .cornerRadius(10)
                        
//                         // Save button
//                         Button(action: changePassword) {
//                             HStack {
//                                 if isSaving {
//                                     ProgressView()
//                                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                         .scaleEffect(0.8)
//                                 } else {
//                                     Text("Update Password")
//                                         .fontWeight(.semibold)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity)
//                             .padding(.vertical, 14)
//                             .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                             .foregroundColor(.white)
//                             .cornerRadius(12)
//                         }
//                         .disabled(!isValid || isSaving)
//                     }
//                     .padding(.horizontal, 25)
//                     .padding(.top, 20)
                    
//                     Spacer(minLength: 100)
//                 }
//             }
//         }
//         .alert("Password Updated", isPresented: $showSuccessAlert) {
//             Button("OK") { onBack() }
//         } message: {
//             Text("Your password has been changed successfully.")
//         }
//     }
    
//     private func changePassword() {
//         guard isValid else { return }
//         isSaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_500_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 showSuccessAlert = true
//             }
//         }
//     }
    
//     private func calculatePasswordStrength(_ password: String) -> PasswordStrength {
//         var score = 0
//         if password.count >= 8 { score += 1 }
//         if password.count >= 12 { score += 1 }
//         if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
//         if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
//         if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
//         if password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil { score += 1 }
        
//         switch score {
//         case 0...2: return .weak
//         case 3...4: return .medium
//         case 5: return .strong
//         default: return .veryStrong
//         }
//     }
// }

// enum PasswordStrength {
//     case weak, medium, strong, veryStrong
    
//     var level: Int {
//         switch self {
//         case .weak: return 1
//         case .medium: return 2
//         case .strong: return 3
//         case .veryStrong: return 4
//         }
//     }
    
//     var color: Color {
//         switch self {
//         case .weak: return .red
//         case .medium: return .orange
//         case .strong: return .yellow
//         case .veryStrong: return .green
//         }
//     }
    
//     var text: String {
//         switch self {
//         case .weak: return "Weak"
//         case .medium: return "Medium"
//         case .strong: return "Strong"
//         case .veryStrong: return "Very Strong"
//         }
//     }
// }

// struct PasswordRequirementRow: View {
//     let text: String
//     let isMet: Bool
    
//     var body: some View {
//         HStack(spacing: 8) {
//             Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
//                 .font(.caption)
//                 .foregroundColor(isMet ? .green : AppColors.greyText.opacity(0.5))
            
//             Text(text)
//                 .font(.caption)
//                 .foregroundColor(isMet ? AppColors.whiteText : AppColors.greyText.opacity(0.7))
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Date of Birth View
// // ================================================================================================

// struct DateOfBirthView: View {
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
    
//     @State private var selectedDate: Date = Date()
//     @State private var isSaving = false
//     @State private var showSuccessAlert = false
    
//     private var minimumDate: Date {
//         Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
//     }
    
//     private var maximumDate: Date {
//         Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
//     }
    
//     private var formattedAge: String {
//         let components = Calendar.current.dateComponents([.year], from: selectedDate, to: Date())
//         return "\(components.year ?? 0) years old"
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Date of Birth", onBack: onBack)
                
//                 VStack(spacing: 24) {
//                     // Info box
//                     HStack(alignment: .top, spacing: 12) {
//                         Image(systemName: "lock.fill")
//                             .foregroundColor(AppColors.accentColor)
                        
//                         VStack(alignment: .leading, spacing: 4) {
//                             Text("Your age is private")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Text("Your date of birth is only used for age verification and is never shown to other users.")
//                                 .font(.caption)
//                                 .foregroundColor(AppColors.greyText)
//                         }
//                     }
//                     .padding()
//                     .background(AppColors.accentColor.opacity(0.1))
//                     .cornerRadius(10)
                    
//                     // Current DOB display
//                     if let dob = rlAppState.currentUser?.dateOfBirth {
//                         VStack(alignment: .leading, spacing: 8) {
//                             Text("Current Date of Birth")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             HStack {
//                                 Image(systemName: "calendar")
//                                     .foregroundColor(AppColors.greyText)
//                                 Text(dob.formatted(date: .long, time: .omitted))
//                                     .foregroundColor(AppColors.whiteText)
//                                 Spacer()
//                             }
//                             .padding()
//                             .background(AppColors.surfaceWhite03)
//                             .cornerRadius(10)
//                         }
//                     }
                    
//                     // Date picker
//                     VStack(alignment: .leading, spacing: 8) {
//                         Text("Select Date of Birth")
//                             .font(.subheadline)
//                             .fontWeight(.medium)
//                             .foregroundColor(AppColors.greyText)
                        
//                         DatePicker(
//                             "",
//                             selection: $selectedDate,
//                             in: minimumDate...maximumDate,
//                             displayedComponents: .date
//                         )
//                         .datePickerStyle(.wheel)
//                         .labelsHidden()
//                         .colorScheme(.dark)
                        
//                         Text(formattedAge)
//                             .font(.caption)
//                             .foregroundColor(AppColors.greyText)
//                             .frame(maxWidth: .infinity, alignment: .center)
//                     }
                    
//                     Spacer()
                    
//                     // Save button
//                     Button(action: saveDateOfBirth) {
//                         HStack {
//                             if isSaving {
//                                 ProgressView()
//                                     .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                     .scaleEffect(0.8)
//                             } else {
//                                 Text("Save")
//                                     .fontWeight(.semibold)
//                             }
//                         }
//                         .frame(maxWidth: .infinity)
//                         .padding(.vertical, 14)
//                         .background(AppColors.accentColor)
//                         .foregroundColor(.white)
//                         .cornerRadius(12)
//                     }
//                     .disabled(isSaving)
//                 }
//                 .padding(.horizontal, 25)
//                 .padding(.top, 20)
//                 .padding(.bottom, 30)
//             }
//         }
//         .onAppear {
//             if let dob = rlAppState.currentUser?.dateOfBirth {
//                 selectedDate = dob
//             }
//         }
//         .alert("Date of Birth Updated", isPresented: $showSuccessAlert) {
//             Button("OK") { onBack() }
//         } message: {
//             Text("Your date of birth has been updated successfully.")
//         }
//     }
    
//     private func saveDateOfBirth() {
//         isSaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_000_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 showSuccessAlert = true
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Trading Interests View
// // ================================================================================================

// struct TradingInterestsView: View {
//     let onBack: () -> Void
    
//     @State private var selectedInterests: Set<String> = ["forex", "stocks"]
//     @State private var isSaving = false
//     @State private var showSuccessAlert = false
    
//     private let interests: [(category: String, items: [(id: String, name: String, icon: String)])] = [
//         ("Markets", [
//             ("forex", "Forex", "dollarsign.circle.fill"),
//             ("stocks", "Stocks", "chart.line.uptrend.xyaxis"),
//             ("crypto", "Cryptocurrency", "bitcoinsign.circle.fill"),
//             ("commodities", "Commodities", "cube.fill"),
//             ("indices", "Indices", "chart.bar.fill"),
//             ("options", "Options", "arrow.left.arrow.right"),
//         ]),
//         ("Trading Styles", [
//             ("daytrading", "Day Trading", "sun.max.fill"),
//             ("swing", "Swing Trading", "waveform.path.ecg"),
//             ("scalping", "Scalping", "bolt.fill"),
//             ("position", "Position Trading", "calendar"),
//             ("algorithmic", "Algorithmic", "cpu.fill"),
//         ]),
//         ("Analysis", [
//             ("technical", "Technical Analysis", "chart.xyaxis.line"),
//             ("fundamental", "Fundamental Analysis", "doc.text.magnifyingglass"),
//             ("sentiment", "Sentiment Analysis", "person.3.fill"),
//             ("priceaction", "Price Action", "candybarphone"),
//         ])
//     ]
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Trading Interests", onBack: onBack)
                
//                 ScrollView {
//                     VStack(spacing: 24) {
//                         // Info text
//                         Text("Select your trading interests to help personalize your experience and connect with like-minded traders.")
//                             .font(.subheadline)
//                             .foregroundColor(AppColors.greyText)
//                             .multilineTextAlignment(.center)
//                             .padding(.horizontal, 25)
//                             .padding(.top, 10)
                        
//                         // Interest categories
//                         ForEach(interests, id: \.category) { category in
//                             VStack(alignment: .leading, spacing: 12) {
//                                 Text(category.category)
//                                     .font(.headline)
//                                     .foregroundColor(AppColors.whiteText)
//                                     .padding(.horizontal, 25)
                                
//                                 LazyVGrid(columns: [
//                                     GridItem(.flexible(), spacing: 12),
//                                     GridItem(.flexible(), spacing: 12)
//                                 ], spacing: 12) {
//                                     ForEach(category.items, id: \.id) { item in
//                                         InterestChip(
//                                             id: item.id,
//                                             name: item.name,
//                                             icon: item.icon,
//                                             isSelected: selectedInterests.contains(item.id),
//                                             onTap: {
//                                                 if selectedInterests.contains(item.id) {
//                                                     selectedInterests.remove(item.id)
//                                                 } else {
//                                                     selectedInterests.insert(item.id)
//                                                 }
//                                             }
//                                         )
//                                     }
//                                 }
//                                 .padding(.horizontal, 25)
//                             }
//                         }
                        
//                         // Selected count
//                         Text("\(selectedInterests.count) interests selected")
//                             .font(.caption)
//                             .foregroundColor(AppColors.greyText)
//                             .padding(.top, 10)
                        
//                         Spacer(minLength: 100)
//                     }
//                     .padding(.top, 10)
//                 }
                
//                 // Save button
//                 VStack {
//                     Button(action: saveInterests) {
//                         HStack {
//                             if isSaving {
//                                 ProgressView()
//                                     .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                     .scaleEffect(0.8)
//                             } else {
//                                 Text("Save Interests")
//                                     .fontWeight(.semibold)
//                             }
//                         }
//                         .frame(maxWidth: .infinity)
//                         .padding(.vertical, 14)
//                         .background(selectedInterests.isEmpty ? AppColors.greyText.opacity(0.5) : AppColors.accentColor)
//                         .foregroundColor(.white)
//                         .cornerRadius(12)
//                     }
//                     .disabled(selectedInterests.isEmpty || isSaving)
//                     .padding(.horizontal, 25)
//                     .padding(.bottom, 30)
//                 }
//                 .background(
//                     LinearGradient(
//                         colors: [AppColors.sheetBackground.opacity(0), AppColors.sheetBackground],
//                         startPoint: .top,
//                         endPoint: .bottom
//                     )
//                     .frame(height: 50)
//                     .offset(y: -50)
//                 )
//             }
//         }
//         .alert("Interests Updated", isPresented: $showSuccessAlert) {
//             Button("OK") { onBack() }
//         } message: {
//             Text("Your trading interests have been updated successfully.")
//         }
//     }
    
//     private func saveInterests() {
//         isSaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_000_000_000)
//             await MainActor.run {
//                 isSaving = false
//                 showSuccessAlert = true
//             }
//         }
//     }
// }

// struct InterestChip: View {
//     let id: String
//     let name: String
//     let icon: String
//     let isSelected: Bool
//     let onTap: () -> Void
    
//     var body: some View {
//         Button(action: onTap) {
//             HStack(spacing: 8) {
//                 Image(systemName: icon)
//                     .font(.system(size: 16))
                
//                 Text(name)
//                     .font(.subheadline)
//                     .fontWeight(.medium)
                
//                 Spacer()
                
//                 if isSelected {
//                     Image(systemName: "checkmark.circle.fill")
//                         .font(.system(size: 16))
//                 }
//             }
//             .foregroundColor(isSelected ? AppColors.accentColor : AppColors.whiteText.opacity(0.8))
//             .padding(.horizontal, 14)
//             .padding(.vertical, 12)
//             .background(isSelected ? AppColors.accentColor.opacity(0.2) : AppColors.surfaceWhite05)
//             .cornerRadius(10)
//             .overlay(
//                 RoundedRectangle(cornerRadius: 10)
//                     .stroke(isSelected ? AppColors.accentColor : Color.clear, lineWidth: 1)
//             )
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Blocked Users View
// // ================================================================================================

// struct BlockedUsersView: View {
//     let onBack: () -> Void
    
//     @State private var blockedUsers: [BlockedUserItem] = BlockedUserItem.sampleData
//     @State private var showUnblockAlert = false
//     @State private var userToUnblock: BlockedUserItem?
//     @State private var isLoading = false
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Blocked Users", onBack: onBack)
                
//                 if isLoading {
//                     Spacer()
//                     ProgressView()
//                         .scaleEffect(1.2)
//                     Spacer()
//                 } else if blockedUsers.isEmpty {
//                     // Empty state
//                     Spacer()
//                     VStack(spacing: 16) {
//                         Image(systemName: "hand.raised.slash.fill")
//                             .font(.system(size: 60))
//                             .foregroundColor(AppColors.greyText.opacity(0.5))
                        
//                         Text("No Blocked Users")
//                             .font(.title3)
//                             .fontWeight(.semibold)
//                             .foregroundColor(AppColors.whiteText)
                        
//                         Text("When you block someone, they'll appear here. Blocked users can't send you messages or see your activity.")
//                             .font(.subheadline)
//                             .foregroundColor(AppColors.greyText)
//                             .multilineTextAlignment(.center)
//                             .padding(.horizontal, 40)
//                     }
//                     Spacer()
//                 } else {
//                     // Info text
//                     Text("Blocked users can't send you messages, see your profile, or interact with you in any guild.")
//                         .font(.caption)
//                         .foregroundColor(AppColors.greyText)
//                         .padding(.horizontal, 25)
//                         .padding(.top, 16)
//                         .padding(.bottom, 8)
                    
//                     // Blocked users list
//                     ScrollView {
//                         LazyVStack(spacing: 12) {
//                             ForEach(blockedUsers) { user in
//                                 BlockedUserRow(
//                                     user: user,
//                                     onUnblock: {
//                                         userToUnblock = user
//                                         showUnblockAlert = true
//                                     }
//                                 )
//                             }
//                         }
//                         .padding(.horizontal, 25)
//                         .padding(.top, 8)
//                     }
//                 }
//             }
//         }
//         .alert("Unblock User", isPresented: $showUnblockAlert) {
//             Button("Cancel", role: .cancel) { }
//             Button("Unblock", role: .destructive) {
//                 if let user = userToUnblock {
//                     unblockUser(user)
//                 }
//             }
//         } message: {
//             if let user = userToUnblock {
//                 Text("Are you sure you want to unblock \(user.displayName)? They'll be able to send you messages and see your activity again.")
//             }
//         }
//     }
    
//     private func unblockUser(_ user: BlockedUserItem) {
//         withAnimation {
//             blockedUsers.removeAll { $0.id == user.id }
//         }
//     }
// }

// struct BlockedUserItem: Identifiable {
//     let id: UUID
//     let displayName: String
//     let username: String
//     let blockedDate: Date
    
//     static let sampleData: [BlockedUserItem] = [
//         BlockedUserItem(id: UUID(), displayName: "Toxic Trader", username: "toxictrader99", blockedDate: Date().addingTimeInterval(-86400 * 5)),
//         BlockedUserItem(id: UUID(), displayName: "Spam Bot", username: "spambot123", blockedDate: Date().addingTimeInterval(-86400 * 30)),
//         BlockedUserItem(id: UUID(), displayName: "Bad Actor", username: "badactor", blockedDate: Date().addingTimeInterval(-86400 * 60)),
//     ]
// }

// struct BlockedUserRow: View {
//     let user: BlockedUserItem
//     let onUnblock: () -> Void
    
//     var body: some View {
//         HStack(spacing: 12) {
//             Circle()
//                 .fill(AppColors.statusNegative20)
//                 .frame(width: 44, height: 44)
//                 .overlay(
//                     Text(String(user.displayName.prefix(2)).uppercased())
//                         .font(.subheadline)
//                         .fontWeight(.semibold)
//                         .foregroundColor(.red)
//                 )
            
//             VStack(alignment: .leading, spacing: 2) {
//                 Text(user.displayName)
//                     .font(.subheadline)
//                     .fontWeight(.medium)
//                     .foregroundColor(AppColors.whiteText)
                
//                 Text("@\(user.username)")
//                     .font(.caption)
//                     .foregroundColor(AppColors.greyText)
                
//                 Text("Blocked \(user.blockedDate.formatted(date: .abbreviated, time: .omitted))")
//                     .font(.caption2)
//                     .foregroundColor(AppColors.greyText.opacity(0.7))
//             }
            
//             Spacer()
            
//             Button(action: onUnblock) {
//                 Text("Unblock")
//                     .font(.caption)
//                     .fontWeight(.semibold)
//                     .foregroundColor(.red)
//                     .padding(.horizontal, 12)
//                     .padding(.vertical, 6)
//                     .background(AppColors.statusNegative15)
//                     .cornerRadius(8)
//             }
//         }
//         .padding(12)
//         .background(AppColors.surfaceWhite03)
//         .cornerRadius(12)
//     }
// }


// // ================================================================================================
// // MARK: - Data & Privacy View
// // ================================================================================================

// struct DataPrivacyView: View {
//     @EnvironmentObject var rlAppState: RLAppState
//     let onBack: () -> Void
    
    
//     @State private var showClearDataAlert = false
//     @State private var isDownloading = false
    
//     // Privacy toggles
//     @State private var activityVisible = true
//     @State private var searchableProfile = true
//     @State private var dataAnalytics = true
//     @State private var personalizedAds = false

//     @State private var isSyncingSettings = false
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             ScrollView {
//                 VStack(spacing: 0) {
//                     SettingsSubViewHeader(title: "Data & Privacy", onBack: onBack)
                    
//                     VStack(spacing: 0) {
//                         // Visibility Section
//                         SettingsSectionHeader(title: "Profile Visibility")
                        
//                         SettingsToggleRow(
//                             icon: "eye.fill",
//                             title: "Activity Visible",
//                             subtitle: "Show your trading activity to others",
//                             isOn: $activityVisible,
//                             iconColor: AppColors.accentColor
//                         )
//                         .onChange(of: activityVisible) { _, newValue in
//                             updateUserSettings(activityVisible: newValue)
//                         }
                        
// //                        SettingsToggleRow(
// //                            icon: "magnifyingglass",
// //                            title: "Searchable Profile",
// //                            subtitle: "Allow others to find you by username",
// //                            isOn: $searchableProfile,
// //                            iconColor: .blue
// //                        )
                        
//                         Divider()
//                             .padding(.vertical, 8)
                        
//                         // Data Usage Section
//                         SettingsSectionHeader(title: "Data Usage")
                        
//                         SettingsToggleRow(
//                             icon: "chart.pie.fill",
//                             title: "Analytics",
//                             subtitle: "Help improve the app with usage data",
//                             isOn: $dataAnalytics,
//                             iconColor: .purple
//                         )
//                         .onChange(of: dataAnalytics) { _, newValue in
//                             updateUserSettings(analyticsEnabled: newValue)
//                         }
                        
//                         SettingsToggleRow(
//                             icon: "rectangle.on.rectangle.angled",
//                             title: "Personalized Content",
//                             subtitle: "Receive personalized recommendations",
//                             isOn: $personalizedAds,
//                             iconColor: .orange
//                         )
//                         .onChange(of: personalizedAds) { _, newValue in
//                             updateUserSettings(personalizedContentEnabled: newValue)
//                         }
                        
//                         Divider()
//                             .padding(.vertical, 8)
                        
//                         // Data Management Section
//                         SettingsSectionHeader(title: "Data Management")
                        
// //                        SettingsButtonRow(
// //                            icon: "arrow.down.doc.fill",
// //                            title: "Download Your Data",
// //                            subtitle: "Get a copy of all your data",
// //                            iconColor: .green
// //                        ) {
// //                            showDownloadDataAlert = true
// //                        }
                        
//                         SettingsButtonRow(
//                             icon: "trash.fill",
//                             title: "Clear Local Data",
//                             subtitle: "Remove cached data from this device",
//                             iconColor: .red
//                         ) {
//                             showClearDataAlert = true
//                         }
                        
//                         // Info box
//                         HStack(alignment: .top, spacing: 12) {
//                             Image(systemName: "info.circle.fill")
//                                 .foregroundColor(.blue)
                            
//                             Text("Your data is encrypted and stored securely. We never sell your personal information to third parties.")
//                                 .font(.caption)
//                                 .foregroundColor(AppColors.greyText)
//                         }
//                         .padding()
//                         .background(AppColors.statusInfo10)
//                         .cornerRadius(10)
//                         .padding(.horizontal, 25)
//                         .padding(.top, 16)
//                     }
                    
//                     Spacer(minLength: 100)
//                 }
//             }
//         }
//         .task {
//             await loadUserSettingsIfNeeded()
//         }
//         .onReceive(rlAppState.$userSettings) { settings in
//             if let settings = settings {
//                 syncSettingsFromState(settings)
//             }
//         }
        
//         .alert("Clear Local Data", isPresented: $showClearDataAlert) {
//             Button("Cancel", role: .cancel) { }
//             Button("Clear", role: .destructive) {
//                 // Clear cached data
//             }
//         } message: {
//             Text("This will remove all cached data from this device. Your account data will not be affected.")
//         }
//     }

//     private func loadUserSettingsIfNeeded() async {
//         if rlAppState.userSettings == nil {
//             try? await rlAppState.fetchUserSettings()
//         }
//     }

//     private func syncSettingsFromState(_ settings: RLUserSettingsDTO) {
//         isSyncingSettings = true
//         activityVisible = settings.activityVisible
//         dataAnalytics = settings.analyticsEnabled
//         personalizedAds = settings.personalizedContentEnabled
//         isSyncingSettings = false
//     }

//     private func updateUserSettings(
//         activityVisible: Bool? = nil,
//         analyticsEnabled: Bool? = nil,
//         personalizedContentEnabled: Bool? = nil
//     ) {
//         guard !isSyncingSettings else { return }
//         Task {
//             do {
//                 let request = RLUserSettingsUpdateRequest(
//                     showOnlineStatus: nil,
//                     allowFriendRequests: nil,
//                     activityVisible: activityVisible,
//                     analyticsEnabled: analyticsEnabled,
//                     personalizedContentEnabled: personalizedContentEnabled
//                 )
//                 let updated = try await rlAppState.updateUserSettings(request)
//                 syncSettingsFromState(updated)
//             } catch {
//                 print("Failed to update user settings: \(error)")
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Help Center View
// // ================================================================================================

// struct HelpCenterView: View {
//     let onBack: () -> Void
    
//     @State private var searchText: String = ""
//     @State private var expandedFAQ: String? = nil
    
//     private let faqCategories: [(category: String, icon: String, color: Color, faqs: [(question: String, answer: String)])] = [
//         ("Getting Started", "play.circle.fill", .green, [
//             ("How do I join a guild?", "You can join a guild by searching for guilds in the Discover tab, or by accepting an invitation from an existing member. Open guilds can be joined directly, while closed guilds require approval from an admin."),
//             ("What are chart markers?", "Chart markers are annotations you can place on trading charts to share analysis with guild members. You can add entry points, targets, stop losses, and custom notes that other members can see and discuss."),
//             ("How does reputation work?", "Reputation is earned through positive contributions to your guild - accurate predictions, helpful analysis, and community engagement. Higher reputation unlocks additional privileges within your guild."),
//         ]),
//         ("Account & Profile", "person.circle.fill", .blue, [
//             ("How do I change my username?", "Go to Settings > Edit Profile to change your username. Usernames must be unique and can only be changed once every 30 days."),
//             ("Can I be in multiple guilds?", "Yes! You can join multiple guilds and switch between them using the guild switcher. Your reputation and contributions are tracked separately for each guild."),
//             ("How do I delete my account?", "Go to Settings > Account Management > Delete Account. This action is permanent and will remove all your data, markers, and messages from all guilds."),
//         ]),
//         ("Trading & Charts", "chart.line.uptrend.xyaxis", AppColors.accentColor, [
//             ("What markets are supported?", "We support Forex, Stocks, Crypto, Commodities, and Indices. The available symbols depend on your data subscription and guild preferences."),
//             ("How do I add a marker to a chart?", "Long-press on any point on the chart to open the marker menu. Select the marker type, add your notes, and tap Save. Your marker will be visible to guild members with chart access."),
//             ("Can I import my own chart data?", "Currently, chart data is provided through our market data partners. Custom data import is planned for a future release."),
//         ]),
//         ("Messaging", "message.fill", .purple, [
//             ("Are my messages private?", "Direct messages are private between you and the recipient. Guild chatroom messages are visible to all guild members with chat access."),
//             ("Can I delete messages?", "You can delete your own messages within 24 hours of sending them. After that, you can request deletion through Settings > Data & Privacy."),
//             ("How do I report a message?", "Long-press on any message and select 'Report'. Our moderation team will review the report and take appropriate action."),
//         ]),
//     ]
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Help Center", onBack: onBack)
                
//                 // Search bar
//                 HStack(spacing: 12) {
//                     Image(systemName: "magnifyingglass")
//                         .foregroundColor(AppColors.greyText)
                    
//                     TextField("Search help topics...", text: $searchText)
//                         .foregroundColor(AppColors.whiteText)
//                 }
//                 .padding()
//                 .background(AppColors.surfaceWhite05)
//                 .cornerRadius(12)
//                 .padding(.horizontal, 25)
//                 .padding(.top, 16)
                
//                 ScrollView {
//                     VStack(spacing: 20) {
//                         ForEach(faqCategories, id: \.category) { category in
//                             let filteredFAQs = searchText.isEmpty ? category.faqs : category.faqs.filter {
//                                 $0.question.localizedCaseInsensitiveContains(searchText) ||
//                                 $0.answer.localizedCaseInsensitiveContains(searchText)
//                             }
                            
//                             if !filteredFAQs.isEmpty {
//                                 FAQCategorySection(
//                                     category: category.category,
//                                     icon: category.icon,
//                                     color: category.color,
//                                     faqs: filteredFAQs,
//                                     expandedFAQ: $expandedFAQ
//                                 )
//                             }
//                         }
                        
//                         // Still need help section
//                         VStack(spacing: 12) {
//                             Image(systemName: "questionmark.bubble.fill")
//                                 .font(.system(size: 40))
//                                 .foregroundColor(AppColors.accentColor)
                            
//                             Text("Still need help?")
//                                 .font(.headline)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Text("Our support team is here to help you with any questions or issues.")
//                                 .font(.subheadline)
//                                 .foregroundColor(AppColors.greyText)
//                                 .multilineTextAlignment(.center)
                            
//                             Button(action: {}) {
//                                 HStack {
//                                     Image(systemName: "envelope.fill")
//                                     Text("Contact Support")
//                                 }
//                                 .fontWeight(.semibold)
//                                 .foregroundColor(.white)
//                                 .padding(.horizontal, 24)
//                                 .padding(.vertical, 12)
//                                 .background(AppColors.accentColor)
//                                 .cornerRadius(10)
//                             }
//                             .padding(.top, 8)
//                         }
//                         .padding(24)
//                         .frame(maxWidth: .infinity)
//                         .background(AppColors.surfaceWhite03)
//                         .cornerRadius(16)
//                         .padding(.horizontal, 25)
                        
//                         Spacer(minLength: 100)
//                     }
//                     .padding(.top, 16)
//                 }
//             }
//         }
//     }
// }

// struct FAQCategorySection: View {
//     let category: String
//     let icon: String
//     let color: Color
//     let faqs: [(question: String, answer: String)]
//     @Binding var expandedFAQ: String?
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             HStack(spacing: 10) {
//                 Image(systemName: icon)
//                     .font(.title3)
//                     .foregroundColor(color)
                
//                 Text(category)
//                     .font(.headline)
//                     .foregroundColor(AppColors.whiteText)
//             }
//             .padding(.horizontal, 25)
            
//             VStack(spacing: 8) {
//                 ForEach(faqs, id: \.question) { faq in
//                     FAQRow(
//                         question: faq.question,
//                         answer: faq.answer,
//                         isExpanded: expandedFAQ == faq.question,
//                         onTap: {
//                             withAnimation(.easeInOut(duration: 0.2)) {
//                                 expandedFAQ = expandedFAQ == faq.question ? nil : faq.question
//                             }
//                         }
//                     )
//                 }
//             }
//             .padding(.horizontal, 25)
//         }
//     }
// }

// struct FAQRow: View {
//     let question: String
//     let answer: String
//     let isExpanded: Bool
//     let onTap: () -> Void
    
//     var body: some View {
//         Button(action: onTap) {
//             VStack(alignment: .leading, spacing: 0) {
//                 HStack {
//                     Text(question)
//                         .font(.subheadline)
//                         .fontWeight(.medium)
//                         .foregroundColor(AppColors.whiteText)
//                         .multilineTextAlignment(.leading)
                    
//                     Spacer()
                    
//                     Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                         .font(.caption)
//                         .foregroundColor(AppColors.greyText)
//                 }
//                 .padding()
                
//                 if isExpanded {
//                     Text(answer)
//                         .font(.subheadline)
//                         .foregroundColor(AppColors.greyText)
//                         .padding(.horizontal)
//                         .padding(.bottom)
//                 }
//             }
//             .background(AppColors.surfaceWhite03)
//             .cornerRadius(12)
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Contact Support View
// // ================================================================================================

// struct ContactSupportView: View {
//     let onBack: () -> Void
    
//     @State private var selectedCategory: SupportCategory = .general
//     @State private var subject: String = ""
//     @State private var message: String = ""
//     @State private var includeDeviceInfo = true
//     @State private var isSending = false
//     @State private var showSuccessAlert = false
    
//     enum SupportCategory: String, CaseIterable {
//         case general = "General Question"
//         case bug = "Report a Bug"
//         case account = "Account Issue"
//         case billing = "Billing & Subscription"
//         case feedback = "Feature Request"
//         case safety = "Safety Concern"
        
//         var icon: String {
//             switch self {
//             case .general: return "questionmark.circle.fill"
//             case .bug: return "ladybug.fill"
//             case .account: return "person.crop.circle.badge.exclamationmark"
//             case .billing: return "creditcard.fill"
//             case .feedback: return "lightbulb.fill"
//             case .safety: return "exclamationmark.shield.fill"
//             }
//         }
        
//         var color: Color {
//             switch self {
//             case .general: return .blue
//             case .bug: return .red
//             case .account: return .orange
//             case .billing: return .green
//             case .feedback: return .yellow
//             case .safety: return .purple
//             }
//         }
//     }
    
//     private var isValid: Bool {
//         !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
//         !message.trimmingCharacters(in: .whitespaces).isEmpty &&
//         message.count >= 20
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             ScrollView {
//                 VStack(spacing: 0) {
//                     SettingsSubViewHeader(title: "Contact Support", onBack: onBack)
                    
//                     VStack(spacing: 24) {
//                         // Category selector
//                         VStack(alignment: .leading, spacing: 8) {
//                             Text("Category")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             ScrollView(.horizontal, showsIndicators: false) {
//                                 HStack(spacing: 10) {
//                                     ForEach(SupportCategory.allCases, id: \.self) { category in
//                                         Button(action: { selectedCategory = category }) {
//                                             HStack(spacing: 6) {
//                                                 Image(systemName: category.icon)
//                                                     .font(.caption)
//                                                 Text(category.rawValue)
//                                                     .font(.caption)
//                                                     .fontWeight(.medium)
//                                             }
//                                             .foregroundColor(selectedCategory == category ? .white : AppColors.whiteText.opacity(0.8))
//                                             .padding(.horizontal, 12)
//                                             .padding(.vertical, 8)
//                                             .background(selectedCategory == category ? category.color : AppColors.surfaceWhite05)
//                                             .cornerRadius(20)
//                                         }
//                                     }
//                                 }
//                             }
//                         }
                        
//                         // Subject field
//                         SettingsTextField(
//                             title: "Subject",
//                             placeholder: "Brief description of your issue",
//                             text: $subject,
//                             icon: "text.alignleft"
//                         )
                        
//                         // Message field
//                         VStack(alignment: .leading, spacing: 8) {
//                             Text("Message")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             TextEditor(text: $message)
//                                 .frame(minHeight: 150)
//                                 .padding(12)
//                                 .background(AppColors.surfaceWhite05)
//                                 .cornerRadius(10)
//                                 .overlay(
//                                     RoundedRectangle(cornerRadius: 10)
//                                         .stroke(AppColors.surfaceWhite10, lineWidth: 1)
//                                 )
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             HStack {
//                                 Text("Please provide as much detail as possible")
//                                     .font(.caption)
//                                     .foregroundColor(AppColors.greyText)
                                
//                                 Spacer()
                                
//                                 Text("\(message.count) characters")
//                                     .font(.caption)
//                                     .foregroundColor(message.count < 20 ? .orange : AppColors.greyText)
//                             }
//                         }
                        
//                         // Device info toggle
//                         HStack {
//                             VStack(alignment: .leading, spacing: 4) {
//                                 Text("Include Device Information")
//                                     .font(.subheadline)
//                                     .foregroundColor(AppColors.whiteText)
                                
//                                 Text("Helps us diagnose technical issues faster")
//                                     .font(.caption)
//                                     .foregroundColor(AppColors.greyText)
//                             }
                            
//                             Spacer()
                            
//                             Toggle("", isOn: $includeDeviceInfo)
//                                 .labelsHidden()
//                                 .tint(AppColors.accentColor)
//                         }
//                         .padding()
//                         .background(AppColors.surfaceWhite03)
//                         .cornerRadius(10)
                        
//                         // Response time info
//                         HStack(alignment: .top, spacing: 12) {
//                             Image(systemName: "clock.fill")
//                                 .foregroundColor(AppColors.accentColor)
                            
//                             VStack(alignment: .leading, spacing: 4) {
//                                 Text("Typical Response Time")
//                                     .font(.subheadline)
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.whiteText)
                                
//                                 Text("We typically respond within 24-48 hours. For urgent issues, responses may be faster.")
//                                     .font(.caption)
//                                     .foregroundColor(AppColors.greyText)
//                             }
//                         }
//                         .padding()
//                         .background(AppColors.accentColor.opacity(0.1))
//                         .cornerRadius(10)
                        
//                         // Submit button
//                         Button(action: submitTicket) {
//                             HStack {
//                                 if isSending {
//                                     ProgressView()
//                                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                         .scaleEffect(0.8)
//                                 } else {
//                                     Image(systemName: "paperplane.fill")
//                                     Text("Send Message")
//                                         .fontWeight(.semibold)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity)
//                             .padding(.vertical, 14)
//                             .background(isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                             .foregroundColor(.white)
//                             .cornerRadius(12)
//                         }
//                         .disabled(!isValid || isSending)
//                     }
//                     .padding(.horizontal, 25)
//                     .padding(.top, 20)
                    
//                     Spacer(minLength: 100)
//                 }
//             }
//         }
//         .alert("Message Sent", isPresented: $showSuccessAlert) {
//             Button("OK") { onBack() }
//         } message: {
//             Text("Your support request has been submitted. You'll receive a confirmation email and we'll get back to you within 24-48 hours.")
//         }
//     }
    
//     private func submitTicket() {
//         guard isValid else { return }
//         isSending = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 2_000_000_000)
//             await MainActor.run {
//                 isSending = false
//                 showSuccessAlert = true
//             }
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Terms & Privacy View
// // ================================================================================================

// struct TermsPrivacyView: View {
//     let onBack: () -> Void
    
//     @State private var selectedTab: Int = 0
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Legal", onBack: onBack)
                
//                 // Tab selector
//                 HStack(spacing: 0) {
//                     ForEach(["Terms of Service", "Privacy Policy"], id: \.self) { tab in
//                         let index = tab == "Terms of Service" ? 0 : 1
//                         Button(action: { selectedTab = index }) {
//                             Text(tab)
//                                 .font(.subheadline)
//                                 .fontWeight(selectedTab == index ? .semibold : .regular)
//                                 .foregroundColor(selectedTab == index ? AppColors.whiteText : AppColors.greyText)
//                                 .frame(maxWidth: .infinity)
//                                 .padding(.vertical, 12)
//                                 .background(
//                                     VStack {
//                                         Spacer()
//                                         Rectangle()
//                                             .fill(selectedTab == index ? AppColors.accentColor : Color.clear)
//                                             .frame(height: 2)
//                                     }
//                                 )
//                         }
//                     }
//                 }
//                 .padding(.horizontal, 25)
                
//                 ScrollView {
//                     VStack(alignment: .leading, spacing: 16) {
//                         if selectedTab == 0 {
//                             // Terms of Service
//                             LegalSection(title: "1. Acceptance of Terms") {
//                                 Text("By accessing and using Traders Guild, you accept and agree to be bound by the terms and provision of this agreement.")
//                             }
                            
//                             LegalSection(title: "2. User Accounts") {
//                                 Text("You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You must immediately notify us of any unauthorized use.")
//                             }
                            
//                             LegalSection(title: "3. User Conduct") {
//                                 Text("You agree not to use the service for any unlawful purpose or in any way that could damage, disable, or impair the service. You agree not to attempt to gain unauthorized access to any part of the service.")
//                             }
                            
//                             LegalSection(title: "4. Content") {
//                                 Text("Users retain ownership of content they create. By posting content, you grant us a non-exclusive license to use, display, and distribute your content within the service.")
//                             }
                            
//                             LegalSection(title: "5. Trading Disclaimer") {
//                                 Text("Traders Guild does not provide financial advice. All trading ideas and analysis shared are for educational purposes only. Users are solely responsible for their trading decisions.")
//                             }
                            
//                             LegalSection(title: "6. Limitation of Liability") {
//                                 Text("To the fullest extent permitted by law, Traders Guild shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the service.")
//                             }
                            
//                         } else {
//                             // Privacy Policy
//                             LegalSection(title: "Information We Collect") {
//                                 Text("We collect information you provide directly (account details, profile information, messages) and information collected automatically (device info, usage data, analytics).")
//                             }
                            
//                             LegalSection(title: "How We Use Your Information") {
//                                 Text("We use your information to provide and improve our services, communicate with you, ensure security, and comply with legal obligations.")
//                             }
                            
//                             LegalSection(title: "Information Sharing") {
//                                 Text("We do not sell your personal information. We may share information with service providers, for legal compliance, or with your consent.")
//                             }
                            
//                             LegalSection(title: "Data Security") {
//                                 Text("We implement industry-standard security measures to protect your data, including encryption, secure servers, and regular security audits.")
//                             }
                            
//                             LegalSection(title: "Your Rights") {
//                                 Text("You have the right to access, correct, or delete your personal data. You can also opt out of certain data collection practices through your account settings.")
//                             }
                            
//                             LegalSection(title: "Contact Us") {
//                                 Text("If you have questions about this privacy policy, please contact us at privacy@tradersguild.com")
//                             }
//                         }
                        
//                         // Last updated
//                         Text("Last updated: January 2026")
//                             .font(.caption)
//                             .foregroundColor(AppColors.greyText)
//                             .padding(.top, 20)
                        
//                         Spacer(minLength: 100)
//                     }
//                     .padding(.horizontal, 25)
//                     .padding(.top, 20)
//                 }
//             }
//         }
//     }
// }

// struct LegalSection<Content: View>: View {
//     let title: String
//     let content: Content
    
//     init(title: String, @ViewBuilder content: () -> Content) {
//         self.title = title
//         self.content = content()
//     }
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 8) {
//             Text(title)
//                 .font(.headline)
//                 .foregroundColor(AppColors.whiteText)
            
//             content
//                 .font(.subheadline)
//                 .foregroundColor(AppColors.greyText)
//                 .lineSpacing(4)
//         }
//     }
// }


// // ================================================================================================
// // MARK: - About View
// // ================================================================================================

// struct AboutView: View {
//     let onBack: () -> Void
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "About", onBack: onBack)
                
//                 ScrollView {
//                     VStack(spacing: 30) {
//                         // App icon and name
//                         VStack(spacing: 16) {
//                             RoundedRectangle(cornerRadius: 24)
//                                 .fill(
//                                     LinearGradient(
//                                         colors: [AppColors.accentColor, AppColors.accentColor.opacity(0.6)],
//                                         startPoint: .topLeading,
//                                         endPoint: .bottomTrailing
//                                     )
//                                 )
//                                 .frame(width: 100, height: 100)
//                                 .overlay(
//                                     Image(systemName: "chart.line.uptrend.xyaxis")
//                                         .font(.system(size: 44))
//                                         .foregroundColor(.white)
//                                 )
                            
//                             Text("Traders Guild")
//                                 .font(.title)
//                                 .fontWeight(.bold)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Text("Social Trading Community")
//                                 .font(.subheadline)
//                                 .foregroundColor(AppColors.greyText)
//                         }
//                         .padding(.top, 30)
                        
//                         // Version info
//                         VStack(spacing: 8) {
//                             AboutInfoRow(label: "Version", value: "1.0.0 (Build 42)")
//                             AboutInfoRow(label: "Platform", value: "iOS 17.0+")
//                             AboutInfoRow(label: "Release Date", value: "January 2026")
//                         }
//                         .padding()
//                         .background(AppColors.surfaceWhite03)
//                         .cornerRadius(12)
//                         .padding(.horizontal, 25)
                        
//                         // Description
//                         VStack(alignment: .leading, spacing: 12) {
//                             Text("About Traders Guild")
//                                 .font(.headline)
//                                 .foregroundColor(AppColors.whiteText)
                            
//                             Text("Traders Guild is a social trading platform that brings traders together in collaborative communities. Share chart analysis, discuss market movements, and learn from fellow traders in real-time.")
//                                 .font(.subheadline)
//                                 .foregroundColor(AppColors.greyText)
//                                 .lineSpacing(4)
//                         }
//                         .padding(.horizontal, 25)
                        
//                         // Links
//                         VStack(spacing: 12) {
//                             AboutLinkRow(icon: "globe", title: "Website", subtitle: "tradersguild.com")
//                             AboutLinkRow(icon: "bird", title: "Twitter", subtitle: "@tradersguild")
//                             AboutLinkRow(icon: "envelope.fill", title: "Email", subtitle: "support@tradersguild.com")
//                         }
//                         .padding(.horizontal, 25)
                        
//                         // Credits
//                         VStack(spacing: 8) {
//                             Text("Made with ❤️ by Al Hennessey")
//                                 .font(.caption)
//                                 .foregroundColor(AppColors.greyText)
                            
//                             Text("© 2026 Traders Guild. All rights reserved.")
//                                 .font(.caption2)
//                                 .foregroundColor(AppColors.greyText.opacity(0.7))
//                         }
//                         .padding(.top, 20)
                        
//                         Spacer(minLength: 100)
//                     }
//                 }
//             }
//         }
//     }
// }

// struct AboutInfoRow: View {
//     let label: String
//     let value: String
    
//     var body: some View {
//         HStack {
//             Text(label)
//                 .font(.subheadline)
//                 .foregroundColor(AppColors.greyText)
            
//             Spacer()
            
//             Text(value)
//                 .font(.subheadline)
//                 .fontWeight(.medium)
//                 .foregroundColor(AppColors.whiteText)
//         }
//     }
// }

// struct AboutLinkRow: View {
//     let icon: String
//     let title: String
//     let subtitle: String
    
//     var body: some View {
//         Button(action: {}) {
//             HStack(spacing: 14) {
//                 Image(systemName: icon)
//                     .font(.headline)
//                     .foregroundColor(AppColors.accentColor)
//                     .frame(width: 24)
                
//                 VStack(alignment: .leading, spacing: 2) {
//                     Text(title)
//                         .font(.subheadline)
//                         .fontWeight(.medium)
//                         .foregroundColor(AppColors.whiteText)
                    
//                     Text(subtitle)
//                         .font(.caption)
//                         .foregroundColor(AppColors.greyText)
//                 }
                
//                 Spacer()
                
//                 Image(systemName: "arrow.up.right")
//                     .font(.caption)
//                     .foregroundColor(AppColors.greyText)
//             }
//             .padding()
//             .background(AppColors.surfaceWhite03)
//             .cornerRadius(10)
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Leave Guild Confirmation View
// // ================================================================================================

// struct LeaveGuildConfirmationView: View {
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
//     let onLeave: () -> Void
    
//     @State private var confirmationText: String = ""
//     @State private var isLeaving = false
    
//     private var guildName: String {
//         rlAppState.currentGuild?.name ?? "this guild"
//     }
    
//     private var isConfirmed: Bool {
//         confirmationText.lowercased() == "leave"
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Leave Guild", onBack: onBack)
                
//                 VStack(spacing: 24) {
//                     // Warning icon
//                     ZStack {
//                         Circle()
//                             .fill(AppColors.statusNegative20)
//                             .frame(width: 80, height: 80)
                        
//                         Image(systemName: "exclamationmark.triangle.fill")
//                             .font(.system(size: 36))
//                             .foregroundColor(.red)
//                     }
//                     .padding(.top, 20)
                    
//                     // Warning text
//                     VStack(spacing: 12) {
//                         Text("Are you sure you want to leave?")
//                             .font(.title3)
//                             .fontWeight(.bold)
//                             .foregroundColor(AppColors.whiteText)
                        
//                         Text("You're about to leave \(guildName). This action will:")
//                             .font(.subheadline)
//                             .foregroundColor(AppColors.greyText)
//                     }
//                     .multilineTextAlignment(.center)
                    
//                     // Consequences list
//                     VStack(alignment: .leading, spacing: 12) {
//                         LeaveConsequenceRow(text: "Remove you from all guild chatrooms")
//                         LeaveConsequenceRow(text: "Delete your guild-specific reputation")
//                         LeaveConsequenceRow(text: "Remove your markers from guild charts")
//                         LeaveConsequenceRow(text: "End your guild membership immediately")
//                     }
//                     .padding()
//                     .background(AppColors.statusNegative10)
//                     .cornerRadius(12)
                    
//                     // Confirmation input
//                     VStack(alignment: .leading, spacing: 8) {
//                         Text("Type \"leave\" to confirm")
//                             .font(.subheadline)
//                             .fontWeight(.medium)
//                             .foregroundColor(AppColors.greyText)
                        
//                         TextField("", text: $confirmationText)
//                             .textInputAutocapitalization(.never)
//                             .padding()
//                             .background(AppColors.surfaceWhite05)
//                             .cornerRadius(10)
//                             .overlay(
//                                 RoundedRectangle(cornerRadius: 10)
//                                     .stroke(isConfirmed ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
//                             )
//                             .foregroundColor(AppColors.whiteText)
//                     }
                    
//                     // Buttons
//                     VStack(spacing: 12) {
//                         Button(action: leaveGuild) {
//                             HStack {
//                                 if isLeaving {
//                                     ProgressView()
//                                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                         .scaleEffect(0.8)
//                                 } else {
//                                     Image(systemName: "rectangle.portrait.and.arrow.right")
//                                     Text("Leave Guild")
//                                         .fontWeight(.semibold)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity)
//                             .padding(.vertical, 14)
//                             .background(isConfirmed ? AppColors.statusNegative : AppColors.statusNegative30)
//                             .foregroundColor(.white)
//                             .cornerRadius(12)
//                         }
//                         .disabled(!isConfirmed || isLeaving)
                        
//                         Button(action: onBack) {
//                             Text("Cancel")
//                                 .fontWeight(.semibold)
//                                 .frame(maxWidth: .infinity)
//                                 .padding(.vertical, 14)
//                                 .background(AppColors.surfaceWhite05)
//                                 .foregroundColor(AppColors.whiteText)
//                                 .cornerRadius(12)
//                         }
//                     }
//                 }
//                 .padding(.horizontal, 25)
                
//                 Spacer()
//             }
//         }
//     }
    
//     private func leaveGuild() {
//         guard isConfirmed else { return }
//         isLeaving = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 1_500_000_000)
//             await MainActor.run {
//                 isLeaving = false
//                 onLeave()
//             }
//         }
//     }
// }

// struct LeaveConsequenceRow: View {
//     let text: String
    
//     var body: some View {
//         HStack(spacing: 10) {
//             Image(systemName: "xmark.circle.fill")
//                 .font(.caption)
//                 .foregroundColor(.red)
            
//             Text(text)
//                 .font(.subheadline)
//                 .foregroundColor(AppColors.whiteText.opacity(0.9))
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Delete Account Confirmation View
// // ================================================================================================

// struct DeleteAccountConfirmationView: View {
//     @EnvironmentObject var rlAppState: RLAppState
    
//     let onBack: () -> Void
//     let onDelete: () -> Void
    
//     @State private var confirmationText: String = ""
//     @State private var password: String = ""
//     @State private var showPassword = false
//     @State private var isDeleting = false
//     @State private var currentStep = 1
    
//     private var isConfirmed: Bool {
//         confirmationText.lowercased() == "delete my account"
//     }
    
//     private var canProceed: Bool {
//         currentStep == 1 || (isConfirmed && !password.isEmpty)
//     }
    
//     var body: some View {
//         ZStack {
//             AppColors.sheetBackground
//                 .ignoresSafeArea()
            
//             VStack(spacing: 0) {
//                 SettingsSubViewHeader(title: "Delete Account", onBack: onBack)
                
//                 ScrollView {
//                     VStack(spacing: 24) {
//                         // Warning icon
//                         ZStack {
//                             Circle()
//                                 .fill(AppColors.statusNegative20)
//                                 .frame(width: 80, height: 80)
                            
//                             Image(systemName: "trash.fill")
//                                 .font(.system(size: 36))
//                                 .foregroundColor(.red)
//                         }
//                         .padding(.top, 20)
                        
//                         // Progress indicator
//                         HStack(spacing: 8) {
//                             ForEach(1...2, id: \.self) { step in
//                                 Circle()
//                                     .fill(step <= currentStep ? AppColors.statusNegative : AppColors.surfaceWhite20)
//                                     .frame(width: 10, height: 10)
//                             }
//                         }
                        
//                         if currentStep == 1 {
//                             // Step 1: Warning
//                             VStack(spacing: 16) {
//                                 Text("This action is permanent")
//                                     .font(.title3)
//                                     .fontWeight(.bold)
//                                     .foregroundColor(AppColors.whiteText)
                                
//                                 Text("Deleting your account will permanently remove all your data. This cannot be undone.")
//                                     .font(.subheadline)
//                                     .foregroundColor(AppColors.greyText)
//                                     .multilineTextAlignment(.center)
//                             }
                            
//                             // What will be deleted
//                             VStack(alignment: .leading, spacing: 12) {
//                                 Text("The following will be permanently deleted:")
//                                     .font(.subheadline)
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.whiteText)
                                
//                                 DeleteItemRow(text: "Your profile and account settings")
//                                 DeleteItemRow(text: "All messages and chat history")
//                                 DeleteItemRow(text: "All chart markers and analysis")
//                                 DeleteItemRow(text: "Guild memberships and reputation")
//                                 DeleteItemRow(text: "Friends list and connections")
//                                 DeleteItemRow(text: "All awards and achievements")
//                             }
//                             .padding()
//                             .background(AppColors.statusNegative10)
//                             .cornerRadius(12)
                            
//                             Button(action: { currentStep = 2 }) {
//                                 Text("I Understand, Continue")
//                                     .fontWeight(.semibold)
//                                     .frame(maxWidth: .infinity)
//                                     .padding(.vertical, 14)
//                                     .background(AppColors.statusNegative)
//                                     .foregroundColor(.white)
//                                     .cornerRadius(12)
//                             }
                            
//                         } else {
//                             // Step 2: Confirmation
//                             VStack(spacing: 16) {
//                                 Text("Confirm Account Deletion")
//                                     .font(.title3)
//                                     .fontWeight(.bold)
//                                     .foregroundColor(AppColors.whiteText)
                                
//                                 Text("To confirm, please type \"delete my account\" and enter your password.")
//                                     .font(.subheadline)
//                                     .foregroundColor(AppColors.greyText)
//                                     .multilineTextAlignment(.center)
//                             }
                            
//                             // Confirmation input
//                             VStack(alignment: .leading, spacing: 8) {
//                                 Text("Type \"delete my account\"")
//                                     .font(.subheadline)
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.greyText)
                                
//                                 TextField("", text: $confirmationText)
//                                     .textInputAutocapitalization(.never)
//                                     .padding()
//                                     .background(AppColors.surfaceWhite05)
//                                     .cornerRadius(10)
//                                     .overlay(
//                                         RoundedRectangle(cornerRadius: 10)
//                                             .stroke(isConfirmed ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
//                                     )
//                                     .foregroundColor(AppColors.whiteText)
//                             }
                            
//                             // Password field
//                             SettingsSecureField(
//                                 title: "Password",
//                                 placeholder: "Enter your password",
//                                 text: $password,
//                                 showPassword: $showPassword
//                             )
                            
//                             // Delete button
//                             Button(action: deleteAccount) {
//                                 HStack {
//                                     if isDeleting {
//                                         ProgressView()
//                                             .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                             .scaleEffect(0.8)
//                                     } else {
//                                         Image(systemName: "trash.fill")
//                                         Text("Permanently Delete Account")
//                                             .fontWeight(.semibold)
//                                     }
//                                 }
//                                 .frame(maxWidth: .infinity)
//                                 .padding(.vertical, 14)
//                                 .background(canProceed ? AppColors.statusNegative : AppColors.statusNegative30)
//                                 .foregroundColor(.white)
//                                 .cornerRadius(12)
//                             }
//                             .disabled(!canProceed || isDeleting)
                            
//                             Button(action: { currentStep = 1 }) {
//                                 Text("Go Back")
//                                     .fontWeight(.medium)
//                                     .foregroundColor(AppColors.greyText)
//                             }
//                         }
                        
//                         // Cancel button
//                         Button(action: onBack) {
//                             Text("Cancel")
//                                 .fontWeight(.semibold)
//                                 .frame(maxWidth: .infinity)
//                                 .padding(.vertical, 14)
//                                 .background(AppColors.surfaceWhite05)
//                                 .foregroundColor(AppColors.whiteText)
//                                 .cornerRadius(12)
//                         }
                        
//                         Spacer(minLength: 100)
//                     }
//                     .padding(.horizontal, 25)
//                 }
//             }
//         }
//     }
    
//     private func deleteAccount() {
//         guard canProceed else { return }
//         isDeleting = true
        
//         Task {
//             try? await Task.sleep(nanoseconds: 2_000_000_000)
//             await MainActor.run {
//                 isDeleting = false
//                 onDelete()
//             }
//         }
//     }
// }

// struct DeleteItemRow: View {
//     let text: String
    
//     var body: some View {
//         HStack(spacing: 10) {
//             Image(systemName: "trash.fill")
//                 .font(.caption)
//                 .foregroundColor(.red)
            
//             Text(text)
//                 .font(.subheadline)
//                 .foregroundColor(AppColors.whiteText.opacity(0.9))
//         }
//     }
// }


// // ================================================================================================
// // MARK: - Reusable Components
// // ================================================================================================

// struct SettingsSubViewHeader: View {
//     let title: String
//     let onBack: () -> Void
    
//     var body: some View {
//         HStack {
//             Button(action: onBack) {
//                 HStack(spacing: 6) {
//                     Image(systemName: "chevron.left")
//                         .font(.headline)
//                     Text("Back")
//                         .font(.headline)
//                 }
//                 .foregroundColor(AppColors.whiteText)
//             }
            
//             Spacer()
            
//             Text(title)
//                 .font(.title2)
//                 .fontWeight(.bold)
//                 .foregroundColor(AppColors.whiteText)
            
//             Spacer()
            
//             // Invisible button for balance
//             HStack(spacing: 6) {
//                 Image(systemName: "chevron.left")
//                     .font(.headline)
//                 Text("Back")
//                     .font(.headline)
//             }
//             .opacity(0)
//         }
//         .padding(.horizontal, 25)
//         .padding(.top, 20)
//         .padding(.bottom, 10)
//     }
// }

// struct SettingsTextField: View {
//     let title: String
//     let placeholder: String
//     @Binding var text: String
//     var icon: String? = nil
//     var error: String? = nil
//     var prefix: String? = nil
//     var keyboardType: UIKeyboardType = .default
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 8) {
//             Text(title)
//                 .font(.subheadline)
//                 .fontWeight(.medium)
//                 .foregroundColor(AppColors.greyText)
            
//             HStack(spacing: 12) {
//                 if let icon = icon {
//                     Image(systemName: icon)
//                         .foregroundColor(error != nil ? .red : AppColors.greyText)
//                 }
                
//                 if let prefix = prefix {
//                     Text(prefix)
//                         .foregroundColor(AppColors.greyText)
//                 }
                
//                 TextField(placeholder, text: $text)
//                     .foregroundColor(AppColors.whiteText)
//                     .keyboardType(keyboardType)
//                     .textInputAutocapitalization(.never)
//             }
//             .padding()
//             .background(AppColors.surfaceWhite05)
//             .cornerRadius(10)
//             .overlay(
//                 RoundedRectangle(cornerRadius: 10)
//                     .stroke(error != nil ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
//             )
            
//             if let error = error {
//                 Text(error)
//                     .font(.caption)
//                     .foregroundColor(.red)
//             }
//         }
//     }
// }

// struct SettingsSecureField: View {
//     let title: String
//     let placeholder: String
//     @Binding var text: String
//     @Binding var showPassword: Bool
//     var error: String? = nil
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 8) {
//             Text(title)
//                 .font(.subheadline)
//                 .fontWeight(.medium)
//                 .foregroundColor(AppColors.greyText)
            
//             HStack(spacing: 12) {
//                 Image(systemName: "lock.fill")
//                     .foregroundColor(error != nil ? .red : AppColors.greyText)
                
//                 if showPassword {
//                     TextField(placeholder, text: $text)
//                         .foregroundColor(AppColors.whiteText)
//                         .textInputAutocapitalization(.never)
//                 } else {
//                     SecureField(placeholder, text: $text)
//                         .foregroundColor(AppColors.whiteText)
//                         .textInputAutocapitalization(.never)
//                 }
                
//                 Button(action: { showPassword.toggle() }) {
//                     Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
//                         .foregroundColor(AppColors.greyText)
//                 }
//             }
//             .padding()
//             .background(AppColors.surfaceWhite05)
//             .cornerRadius(10)
//             .overlay(
//                 RoundedRectangle(cornerRadius: 10)
//                     .stroke(error != nil ? AppColors.statusNegative : AppColors.surfaceWhite10, lineWidth: 1)
//             )
            
//             if let error = error {
//                 Text(error)
//                     .font(.caption)
//                     .foregroundColor(.red)
//             }
//         }
//     }
// }

// // NOTE: SettingsSectionHeader, SettingsToggleRow, and SettingsButtonRow
// // are defined in MessagingSettings.swift and shared across the app.
