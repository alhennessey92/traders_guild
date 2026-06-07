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
                Text("Step 5 of 5")
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

                                Text("You'll start here in your System Guild — try the tutorial and explore. You can join or create a guild anytime from the menu.")
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

                                Text("Setting up your System Guild")
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)

                                Text("Continue to get set up in your System Guild.")
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
            return "Everyone starts in a System Guild — a relaxed space to learn the ropes before joining a community."
        }
        return "Everyone starts in a System Guild — a relaxed space to learn the ropes before joining a community."
    }

    private var actionTitle: String {
        if isContinuing { return "Continuing..." }
        if isRetryAssignmentState { return "Retry assignment" }
        if shouldShowAssignedFallback, let selectedGuild {
            return "Finish with \(selectedGuild.name)"
        }
        if requiresGuildSelection { return "Select a Guild to Finish" }
        if let selectedGuild { return "Finish with \(selectedGuild.name)" }
        if availableGuilds.isEmpty { return "Finish Registration" }
        return "Finish Registration"
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

        // New users always start in a system (onboarding) guild — a stable home
        // with the tutorial. They browse/join real guilds from inside the app
        // afterwards (most public guilds are invite/approval-only anyway).
        availableGuilds = []
        await prepareAssignedFallbackGuild()
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
                if rlAppState.currentUser?.isVerified == true {
                    _ = try await rlAppState.joinGuild(guildId: selectedGuild.id, showTransition: false)
                } else {
                    // Account is created but the email isn't verified yet, and the
                    // backend gates guild joins on verification. Defer the join
                    // until after the email-verification step so the user reaches
                    // the code-entry screen instead of a dead-end error toast.
                    rlAppState.setPendingOnboardingGuildId(selectedGuild.id)
                }
            }
            await applyProfileDraftIfNeeded()
            finishRegistrationAfterGuildSelection()
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
            await applyProfileDraftIfNeeded()
            finishRegistrationAfterGuildSelection()
            return
        }

        try await ensureRegisteredIfNeeded()

        do {
            let assignedGuild = try await rlAppState.assignOnboardingGuild(showTransition: false).guild
            selectedGuild = assignedGuild
            guildMode = .assignedFallbackMode
            assignmentErrorMessage = nil
            await applyProfileDraftIfNeeded()
            finishRegistrationAfterGuildSelection()
        } catch {
            if await recoverAssignedGuildFromCurrentState() {
                assignmentErrorMessage = nil
                await applyProfileDraftIfNeeded()
                finishRegistrationAfterGuildSelection()
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

    private func finishRegistrationAfterGuildSelection() {
        rlAppState.onboardingState = .guildSelected
        if rlAppState.currentUser?.isVerified == false {
            path = [.emailVerification]
        } else {
            rlAppState.completeOnboardingAndEnterApp()
        }
    }

    private func applyProfileDraftIfNeeded() async {
        do {
            if let imageData = data.profileAvatarImageData {
                _ = try await rlAppState.uploadAvatar(imageData: imageData, mimeType: "image/jpeg")
            }

            let orderedSelectedNames = RLTradingInterestsCatalog.allItems
                .map(\.name)
                .filter { data.selectedInterests.contains($0) }

            let tradingInterests = RLTradingInterestsCatalog.allItems
                .filter { data.selectedInterests.contains($0.name) }
                .map { base in
                    RLTradingInterestItem(
                        name: base.name,
                        icon: base.icon,
                        isPrimary: orderedSelectedNames.first == base.name
                    )
                }

            let links: [RLSocialLinkItem] = [
                RLSocialLinkItem(platform: "twitter", username: RLAuthValidator.trimmed(data.profileTwitterHandle), url: nil),
                RLSocialLinkItem(platform: "discord", username: RLAuthValidator.trimmed(data.profileDiscordHandle), url: nil),
                RLSocialLinkItem(platform: "telegram", username: RLAuthValidator.trimmed(data.profileTelegramHandle), url: nil),
                RLSocialLinkItem(platform: "tradingview", username: RLAuthValidator.trimmed(data.profileTradingViewHandle), url: nil),
                RLSocialLinkItem(platform: "youtube", username: RLAuthValidator.trimmed(data.profileYoutubeHandle), url: nil),
            ].filter { !$0.username.isEmpty }

            let bio = RLAuthValidator.trimmed(data.profileBio)
            let tradingStyle = RLAuthValidator.trimmed(data.profileTradingStyle)
            let language = RLAuthValidator.trimmed(data.language)
            let location = RLAuthValidator.trimmed(data.location)

            let hasProfileFields = !bio.isEmpty
                || !tradingStyle.isEmpty
                || !language.isEmpty
                || !location.isEmpty
                || !links.isEmpty
                || !tradingInterests.isEmpty

            guard hasProfileFields else { return }

            let request = RLUserProfileUpdateRequest(
                bio: bio.isEmpty ? nil : bio,
                language: language.isEmpty ? nil : language,
                location: location.isEmpty ? nil : location,
                tradingStyle: tradingStyle.isEmpty ? nil : tradingStyle,
                socialLinks: links.isEmpty ? nil : links,
                tradingInterests: tradingInterests.isEmpty ? nil : tradingInterests
            )
            _ = try await rlAppState.updateCurrentUserProfile(request)
        } catch {
            // Optional profile details should not block the user from entering their guild.
        }
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
        selectedLanguageCode.isEmpty ? "Select language" : LocaleOptionCatalog.languageLabel(for: selectedLanguageCode)
    }

    private var selectedCountryLabel: String {
        selectedCountryCode.isEmpty ? "Select country" : LocaleOptionCatalog.countryDisplay(for: selectedCountryCode)
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Step indicator
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Step 4 of 5")
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
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(index < 4 ? AppColors.whiteText : AppColors.whiteText.opacity(0.25))
                                .frame(height: 5)
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
                                        Button(LocaleOptionCatalog.countryDisplay(for: option.code)) {
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
                        clearProfileDraft()
                        path.append(.guild)
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
            if bio.isEmpty {
                bio = data.profileBio
            }
            if selectedLanguageCode.isEmpty {
                selectedLanguageCode = languageCode(from: data.language)
            }
            if selectedCountryCode.isEmpty {
                selectedCountryCode = countryCode(from: data.location)
            }
            if tradingStyle.isEmpty {
                tradingStyle = data.profileTradingStyle
            }
            if twitterHandle.isEmpty {
                twitterHandle = data.profileTwitterHandle
            }
            if discordHandle.isEmpty {
                discordHandle = data.profileDiscordHandle
            }
            if telegramHandle.isEmpty {
                telegramHandle = data.profileTelegramHandle
            }
            if tradingViewHandle.isEmpty {
                tradingViewHandle = data.profileTradingViewHandle
            }
            if youtubeHandle.isEmpty {
                youtubeHandle = data.profileYoutubeHandle
            }
            if selectedAvatarImage == nil,
               let imageData = data.profileAvatarImageData {
                selectedAvatarImage = UIImage(data: imageData)
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

        saveProfileDraft()
        path.append(.guild)
    }

    private func saveProfileDraft() {
        data.profileBio = RLAuthValidator.trimmed(bio)
        data.profileTradingStyle = RLAuthValidator.trimmed(tradingStyle)
        data.profileTwitterHandle = RLAuthValidator.trimmed(twitterHandle)
        data.profileDiscordHandle = RLAuthValidator.trimmed(discordHandle)
        data.profileTelegramHandle = RLAuthValidator.trimmed(telegramHandle)
        data.profileTradingViewHandle = RLAuthValidator.trimmed(tradingViewHandle)
        data.profileYoutubeHandle = RLAuthValidator.trimmed(youtubeHandle)
        data.profileAvatarImageData = selectedAvatarImage?.jpegData(compressionQuality: 0.82)
        data.selectedInterests = suggestedInterests
            .map(\.name)
            .filter { selectedInterests.contains($0) }

        data.language = selectedLanguageCode
        data.location = selectedCountryCode
    }

    private func clearProfileDraft() {
        data.profileBio = ""
        data.profileTradingStyle = ""
        data.profileTwitterHandle = ""
        data.profileDiscordHandle = ""
        data.profileTelegramHandle = ""
        data.profileTradingViewHandle = ""
        data.profileYoutubeHandle = ""
        data.profileAvatarImageData = nil
    }

    private func languageCode(from value: String) -> String {
        LocaleOptionCatalog.languageCode(from: value)
    }

    private func countryCode(from value: String) -> String {
        LocaleOptionCatalog.countryCode(from: value)
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
                        GuildCrestView(guild: guild, size: 26)

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
                        Image(systemName: "star.hexagon.fill")
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
