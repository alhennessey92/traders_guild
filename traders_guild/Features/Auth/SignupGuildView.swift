//
//  SignupGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//

import SwiftUI
import UIKit

private enum SignupGuildMode {
    case openSelectionMode
    case assignedFallbackMode
}

struct SignupGuildView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var availableGuilds: [RLGuildDTO] = []
    @State private var isPreparingAccount: Bool = false
    @State private var isLoadingGuilds: Bool = true
    @State private var isContinuing: Bool = false
    @State private var selectedGuild: RLGuildDTO?
    @State private var hasLoadedGuilds: Bool = false
    @State private var guildMode: SignupGuildMode = .openSelectionMode
    @State private var assignmentErrorMessage: String?

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            VStack(spacing: 0) {
                Text("Step 5 of 6")
                    .font(AppFonts.smallNotice())
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                HStack(spacing: 6) {
                    Capsule().fill(AppColors.whiteText).frame(height: 5)
                    Capsule().fill(AppColors.whiteText).frame(height: 5)
                    Capsule().fill(AppColors.whiteText).frame(height: 5)
                    Capsule().fill(AppColors.whiteText).frame(height: 5)
                    Capsule().fill(AppColors.whiteText).frame(height: 5)
                    Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                Text("Choose Your First Guild")
                    .font(.title.bold())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14)
                    .padding(.horizontal, 20)

                Rectangle()
                    .fill(AppColors.surfaceGray40)
                    .frame(height: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if isPreparingAccount {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.whiteText))
                                    .scaleEffect(1.2)

                                Text("Creating your account...")
                                    .foregroundColor(AppColors.greyText)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if isLoadingGuilds {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.whiteText))
                                    .scaleEffect(1.2)

                                Text("Loading available guilds...")
                                    .foregroundColor(AppColors.greyText)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if shouldShowAssignedFallback {
                            VStack(spacing: 14) {
                                if let assignedGuild = selectedGuild {
                                    GuildSelectionRow(
                                        guild: assignedGuild,
                                        isSelected: true,
                                        isInteractive: false
                                    ) {}
                                }

                                Text("You will start in this onboarding guild.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                        } else if availableGuilds.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppColors.greyText.opacity(0.6))

                                Text("No open guilds available right now")
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)

                                Text("Continue to get assigned to an onboarding guild.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                if let assignmentErrorMessage {
                                    VStack(spacing: 10) {
                                        Text(assignmentErrorMessage)
                                            .font(.footnote)
                                            .foregroundColor(AppColors.statusNegative95)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppColors.statusNegative12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(AppColors.statusNegative35, lineWidth: 1)
                                                    )
                                            )

                                        Button("Retry assignment") {
                                            Task { await handleContinue() }
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppColors.whiteText)
                                        .disabled(isPreparingAccount || isLoadingGuilds || isContinuing)
                                        .opacity((isPreparingAccount || isLoadingGuilds || isContinuing) ? 0.6 : 1.0)
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(availableGuilds) { guild in
                                    GuildSelectionRow(
                                        guild: guild,
                                        isSelected: selectedGuild?.id == guild.id
                                    ) {
                                        selectedGuild = guild
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 100)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTapAndDragBackground()
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !rlAppState.isAuthenticated {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                    .disabled(isPreparingAccount || isLoadingGuilds || isContinuing)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .keyboardPinnedBottomInset {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                HStack {
                    Spacer()
                    StandardActionButton(
                        title: actionTitle,
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task { await handleContinue() }
                    }
                    .disabled(continueDisabled)
                    .opacity(continueDisabled ? 0.6 : 1.0)
                    .padding(.top)
                    .padding(.trailing)
                }
            }
            .background(AppColors.sheetBackground)
        }
        .onAppear {
            if !hasLoadedGuilds {
                hasLoadedGuilds = true
                Task { await loadPublicGuilds() }
            }
        }
    }

    private var subtitleText: String {
        if shouldShowAssignedFallback {
            return "No open guilds available, so you were assigned this onboarding guild."
        }
        return "Only open guilds are listed here. Private guilds require owner/admin approval after signup."
    }

    private var actionTitle: String {
        if isContinuing { return "Continuing..." }
        if isRetryAssignmentState { return "Retry assignment" }
        if shouldShowAssignedFallback, let selectedGuild {
            return "Continue with \(selectedGuild.name)"
        }
        if requiresGuildSelection { return "Select a Guild to Continue" }
        if let selectedGuild { return "Continue with \(selectedGuild.name)" }
        if availableGuilds.isEmpty { return "Continue" }
        return "Continue"
    }

    private var continueDisabled: Bool {
        isPreparingAccount || isLoadingGuilds || isContinuing || requiresGuildSelection
    }

    private var shouldShowAssignedFallback: Bool {
        availableGuilds.isEmpty && guildMode == .assignedFallbackMode && selectedGuild != nil
    }

    private var isRetryAssignmentState: Bool {
        availableGuilds.isEmpty && assignmentErrorMessage != nil
    }

    private var requiresGuildSelection: Bool {
        !availableGuilds.isEmpty && selectedGuild == nil
    }

    private func loadPublicGuilds() async {
        isLoadingGuilds = true
        defer { isLoadingGuilds = false }

        do {
            let preferredLanguage = data.language.trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredLocation = data.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let guilds = try await rlAppState.fetchPublicOpenGuilds(
                language: preferredLanguage.isEmpty ? nil : preferredLanguage,
                location: preferredLocation.isEmpty ? nil : preferredLocation
            )
            availableGuilds = guilds
            assignmentErrorMessage = nil

            if guilds.isEmpty {
                await prepareAssignedFallbackGuild()
            } else {
                guildMode = .openSelectionMode
                if let selectedGuild, !guilds.contains(where: { $0.id == selectedGuild.id }) {
                    self.selectedGuild = nil
                }
            }
        } catch is CancellationError {
            return
        } catch {
            // Error surfaced by rlAppState
            if availableGuilds.isEmpty {
                await prepareAssignedFallbackGuild()
            }
        }
    }

    private func prepareAssignedFallbackGuild() async {
        if await recoverAssignedGuildFromCurrentState() {
            assignmentErrorMessage = nil
            return
        }

        do {
            try await ensureRegisteredIfNeeded()
            let assignedGuild = try await rlAppState.assignOnboardingGuild(showTransition: false).guild
            selectedGuild = assignedGuild
            guildMode = .assignedFallbackMode
            assignmentErrorMessage = nil
        } catch {
            if await recoverAssignedGuildFromCurrentState() {
                assignmentErrorMessage = nil
                return
            }
            selectedGuild = nil
            guildMode = .openSelectionMode
            assignmentErrorMessage = "Assignment failed. Retry assignment to continue."
        }
    }

    private func handleContinue() async {
        guard !isContinuing else { return }
        isContinuing = true
        defer {
            isContinuing = false
            isPreparingAccount = false
        }

        do {
            if availableGuilds.isEmpty {
                try await handleNoOpenGuildContinue()
                return
            }

            try await ensureRegisteredIfNeeded()

            if let selectedGuild,
               rlAppState.currentGuild?.id != selectedGuild.id {
                _ = try await rlAppState.joinGuild(guildId: selectedGuild.id, showTransition: false)
            }
            path.append(.profile)
        } catch is CancellationError {
            return
        } catch {
            // Error surfaced by rlAppState
        }
    }

    private func handleNoOpenGuildContinue() async throws {
        if guildMode == .assignedFallbackMode,
           assignmentErrorMessage == nil,
           selectedGuild != nil,
           rlAppState.isAuthenticated {
            path.append(.profile)
            return
        }

        try await ensureRegisteredIfNeeded()

        do {
            let assignedGuild = try await rlAppState.assignOnboardingGuild(showTransition: false).guild
            selectedGuild = assignedGuild
            guildMode = .assignedFallbackMode
            assignmentErrorMessage = nil
        } catch {
            if await recoverAssignedGuildFromCurrentState() {
                assignmentErrorMessage = nil
                return
            }

            assignmentErrorMessage = "Assignment failed. Retry assignment to continue."
            throw error
        }
    }

    private func ensureRegisteredIfNeeded() async throws {
        if rlAppState.isAuthenticated {
            if data.isAppleSignUp {
                isPreparingAccount = true
                defer { isPreparingAccount = false }
                try await rlAppState.syncAppleOnboardingData(data)
            }
            return
        }
        isPreparingAccount = true
        defer { isPreparingAccount = false }
        try await rlAppState.signUp(data: data, beginOnboarding: true)
        path = [.guild]
    }

    private func recoverAssignedGuildFromCurrentState() async -> Bool {
        if let currentGuild = rlAppState.currentGuild {
            selectedGuild = currentGuild
            guildMode = .assignedFallbackMode
            return true
        }

        do {
            try await rlAppState.fetchUserGuilds()
            if let assignedMembership = rlAppState.userGuilds.first {
                rlAppState.selectGuild(assignedMembership, showTransition: false)
                selectedGuild = assignedMembership.guild
                guildMode = .assignedFallbackMode
                return true
            }
        } catch {
            return false
        }
        return false
    }
}

struct SignupProfileSetupView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var bio: String = ""
    @State private var selectedLanguageCode: String = ""
    @State private var selectedCountryCode: String = ""
    @State private var tradingStyle: String = ""
    @State private var twitterHandle: String = ""
    @State private var discordHandle: String = ""
    @State private var telegramHandle: String = ""
    @State private var tradingViewHandle: String = ""
    @State private var youtubeHandle: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var selectedAvatarImage: UIImage?
    @State private var showingImagePicker: Bool = false
    @State private var isSaving: Bool = false

    private let suggestedInterests: [RLTradingInterestItem] = RLTradingInterestsCatalog.allItems

    private var selectedLanguageLabel: String {
        LocaleOptionCatalog.languages.first(where: { $0.code == selectedLanguageCode })?.label ?? "Select language"
    }

    private var selectedCountryLabel: String {
        LocaleOptionCatalog.countries.first(where: { $0.code == selectedCountryCode })?.label ?? "Select country"
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Step indicator
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Step 6 of 6")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.greyText)

                        Text("Final Touches")
                            .font(.title.bold())
                            .foregroundColor(AppColors.whiteText)

                        Text("Almost done! Add a few basics to personalize your experience. Everything here is optional and editable later.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { _ in
                            Capsule().fill(AppColors.whiteText).frame(height: 5)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Profile Photo section
                    profileSetupSection(title: "Profile Photo") {
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let selectedAvatarImage {
                                        Image(uiImage: selectedAvatarImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else if let avatar = rlAppState.currentUser?.avatarUrl, let url = URL(string: avatar) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            ProgressView()
                                        }
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(16)
                                            .foregroundColor(AppColors.greyText)
                                    }
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppColors.whiteText.opacity(0.3), lineWidth: 1))

                                Button {
                                    showingImagePicker = true
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.whiteText)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.gradientBackgroundDark)
                                    }
                                }
                                .offset(x: 2, y: 2)
                            }

                            Button {
                                showingImagePicker = true
                            } label: {
                                Text(selectedAvatarImage == nil ? "Choose Avatar" : "Change Avatar")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // About You section
                    profileSetupSection(title: "About You") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Language (optional)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)

                                Menu {
                                    Button("Not specified") {
                                        selectedLanguageCode = ""
                                    }
                                    Divider()
                                    ForEach(LocaleOptionCatalog.languages) { option in
                                        Button(option.label) {
                                            selectedLanguageCode = option.code
                                        }
                                    }
                                } label: {
                                    profileDropdownFieldLabel(selectedLanguageCode.isEmpty ? "Select language" : selectedLanguageLabel)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Location (optional)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)

                                Menu {
                                    Button("Not specified") {
                                        selectedCountryCode = ""
                                    }
                                    Divider()
                                    ForEach(LocaleOptionCatalog.countries) { option in
                                        Button(option.label) {
                                            selectedCountryCode = option.code
                                        }
                                    }
                                } label: {
                                    profileDropdownFieldLabel(selectedCountryCode.isEmpty ? "Select country" : selectedCountryLabel)
                                }
                            }

                            StandardTextFieldView(title: "Trading Style (optional)", text: $tradingStyle)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio (optional)")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                                    .padding(.horizontal, 4)

                                TextEditor(text: $bio)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .font(.body)
                                    .foregroundColor(AppColors.whiteText)
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }

                    // Trading Interests section
                    profileSetupSection(title: "Trading Interests") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(suggestedInterests) { interest in
                                Button {
                                    if selectedInterests.contains(interest.name) {
                                        selectedInterests.remove(interest.name)
                                    } else {
                                        selectedInterests.insert(interest.name)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: interest.icon)
                                            .font(.caption)
                                        Text(interest.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedInterests.contains(interest.name) ? AppColors.gradientBackgroundDark : AppColors.whiteText)
                                    .background(
                                        Capsule().fill(selectedInterests.contains(interest.name) ? AppColors.whiteText : AppColors.whiteText.opacity(0.08))
                                    )
                                }
                            }
                        }
                    }

                    // Social Connections section
                    profileSetupSection(title: "Social Connections") {
                        VStack(spacing: 10) {
                            profileSocialField(icon: "at", title: "X / Twitter username", text: $twitterHandle)
                            profileSocialField(icon: "bubble.left.fill", title: "Discord username", text: $discordHandle)
                            profileSocialField(icon: "paperplane.fill", title: "Telegram username", text: $telegramHandle)
                            profileSocialField(icon: "chart.xyaxis.line", title: "TradingView username", text: $tradingViewHandle)
                            profileSocialField(icon: "play.rectangle.fill", title: "YouTube channel", text: $youtubeHandle)
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !rlAppState.isAuthenticated {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                    .disabled(isSaving)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .keyboardPinnedBottomInset {
            VStack(spacing: 10) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                HStack(spacing: 10) {
                    Button {
                        if rlAppState.currentUser?.isVerified == false {
                            path.append(.emailVerification)
                        } else {
                            rlAppState.completeOnboardingAndEnterApp()
                        }
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                    }
                    .disabled(isSaving)

                    Spacer()

                    StandardActionButton(
                        title: isSaving ? "Saving..." : "Continue",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task { await saveAndContinue() }
                    }
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.7 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .background(AppColors.sheetBackground)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedAvatarImage)
        }
        .onAppear {
            if selectedInterests.isEmpty, !data.selectedInterests.isEmpty {
                selectedInterests = Set(data.selectedInterests)
            }
            if selectedLanguageCode.isEmpty {
                // data.language stores a code from locale detection
                selectedLanguageCode = data.language
            }
            if selectedCountryCode.isEmpty {
                // data.location stores a code from locale detection
                selectedCountryCode = data.location
            }
        }
    }

    private func profileSetupSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.whiteText)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func profileDropdownFieldLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundColor(AppColors.whiteText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.greyText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func profileSocialField(icon: String, title: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.accentColor)
                .frame(width: 24)

            TextField(title, text: text)
                .font(.body)
                .foregroundColor(AppColors.whiteText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func saveAndContinue() async {
        isSaving = true
        defer { isSaving = false }

        do {
            if let selectedAvatarImage {
                if let imageData = selectedAvatarImage.jpegData(compressionQuality: 0.82) {
                    _ = try await rlAppState.uploadAvatar(imageData: imageData, mimeType: "image/jpeg")
                }
            }

            let orderedSelectedNames = suggestedInterests
                .map(\.name)
                .filter { selectedInterests.contains($0) }

            let selected = suggestedInterests.map { base -> RLTradingInterestItem in
                RLTradingInterestItem(
                    name: base.name,
                    icon: base.icon,
                    isPrimary: orderedSelectedNames.first == base.name
                )
            }.filter { selectedInterests.contains($0.name) }

            let links: [RLSocialLinkItem] = [
                RLSocialLinkItem(platform: "twitter", username: RLAuthValidator.trimmed(twitterHandle), url: nil),
                RLSocialLinkItem(platform: "discord", username: RLAuthValidator.trimmed(discordHandle), url: nil),
                RLSocialLinkItem(platform: "telegram", username: RLAuthValidator.trimmed(telegramHandle), url: nil),
                RLSocialLinkItem(platform: "tradingview", username: RLAuthValidator.trimmed(tradingViewHandle), url: nil),
                RLSocialLinkItem(platform: "youtube", username: RLAuthValidator.trimmed(youtubeHandle), url: nil),
            ].filter { !$0.username.isEmpty }

            let languageLabel = LocaleOptionCatalog.languages.first(where: { $0.code == selectedLanguageCode })?.label
            let countryLabel = LocaleOptionCatalog.countries.first(where: { $0.code == selectedCountryCode })?.label

            let request = RLUserProfileUpdateRequest(
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                language: languageLabel,
                location: countryLabel,
                tradingStyle: tradingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tradingStyle.trimmingCharacters(in: .whitespacesAndNewlines),
                socialLinks: links.isEmpty ? nil : links,
                tradingInterests: selected.isEmpty ? nil : selected
            )
            _ = try await rlAppState.updateCurrentUserProfile(request)
            data.language = languageLabel ?? ""
            data.location = countryLabel ?? ""
        } catch {
            // Error surfaced by RLAppState
        }

        // Navigate to email verification step if user is not yet verified
        if rlAppState.currentUser?.isVerified == false {
            path.append(.emailVerification)
        } else {
            rlAppState.completeOnboardingAndEnterApp()
        }
    }
}

// MARK: - Guild Selection Row Component
struct GuildSelectionRow: View {
    let guild: RLGuildDTO
    let isSelected: Bool
    let isInteractive: Bool
    let onTap: () -> Void

    init(
        guild: RLGuildDTO,
        isSelected: Bool,
        isInteractive: Bool = true,
        onTap: @escaping () -> Void
    ) {
        self.guild = guild
        self.isSelected = isSelected
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.title2)
                            .foregroundColor(AppColors.accentColor.opacity(0.6))

                        Text(guild.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        + Text(" Guild")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentColor)
                    }

                    Text("\(guild.memberCount) Members - \(guild.statusText)")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.leading, 15)

                    HStack(spacing: 3) {
                        Text(guild.ownerDisplayName ?? guild.ownerUsername ?? "Unknown Owner")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)

                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)

                        Text("@\(guild.ownerUsername ?? "owner")")
                            .font(.caption)
                            .foregroundColor(AppColors.accentColor)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)

                    HStack(spacing: 3) {
                        Circle()
                            .fill(AppColors.statusPositive)
                            .frame(width: 6, height: 6)
                        Text("\(guild.membersOnline) online")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                    }
                    .padding(.leading, 15)

                    HStack(spacing: 2) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text(guild.reputationDisplay)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        Text(" Guild Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.6))
                    .font(.system(size: 20))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? AppColors.whiteText.opacity(0.36) : AppColors.whiteText.opacity(0.28),
                                lineWidth: isSelected ? 1.2 : 1.15
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .opacity(1.0)
    }
}
