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
                Text("Choose Your First Guild")
                    .font(.title.bold())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14)
                    .padding(.horizontal, 20)

                Rectangle()
                    .fill(Color.gray.opacity(0.4))
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
                                            .foregroundColor(Color.red.opacity(0.95))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.red.opacity(0.12))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
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
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if !path.isEmpty { path.removeLast() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(AppColors.unhighlightedButtonBackground)
                }
                .disabled(isPreparingAccount || isLoadingGuilds || isContinuing)
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(Color.gray.opacity(0.3))

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
            let guilds = try await rlAppState.fetchPublicOpenGuilds()
            availableGuilds = guilds
            assignmentErrorMessage = nil

            if guilds.isEmpty {
                _ = await recoverAssignedGuildFromCurrentState()
                if guildMode != .assignedFallbackMode {
                    selectedGuild = nil
                    guildMode = .openSelectionMode
                }
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
                _ = await recoverAssignedGuildFromCurrentState()
            }
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
        guard !rlAppState.isAuthenticated else { return }
        isPreparingAccount = true
        try await rlAppState.signUp(data: data, beginOnboarding: true)
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
    @State private var location: String = ""
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

    private let suggestedInterests: [RLTradingInterestItem] = [
        RLTradingInterestItem(name: "Forex", icon: "dollarsign.circle.fill", isPrimary: false),
        RLTradingInterestItem(name: "Stocks", icon: "chart.line.uptrend.xyaxis", isPrimary: false),
        RLTradingInterestItem(name: "Crypto", icon: "bitcoinsign.circle.fill", isPrimary: false),
        RLTradingInterestItem(name: "Day Trading", icon: "sun.max.fill", isPrimary: false),
        RLTradingInterestItem(name: "Swing Trading", icon: "waveform.path.ecg", isPrimary: false),
        RLTradingInterestItem(name: "Technical Analysis", icon: "chart.xyaxis.line", isPrimary: false)
    ]

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("Finish Setting Up Your Profile")
                        .font(.title.bold())
                        .foregroundColor(AppColors.whiteText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Text("Add a few basics to personalize your experience. You can skip this and edit later in Settings.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Avatar")
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 20)

                        HStack(spacing: 12) {
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
                                        .padding(10)
                                        .foregroundColor(AppColors.greyText)
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColors.whiteText.opacity(0.3), lineWidth: 1))

                            Button {
                                showingImagePicker = true
                            } label: {
                                Text(selectedAvatarImage == nil ? "Choose Avatar" : "Change Avatar")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.gradientBackgroundDark)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(AppColors.whiteText)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    StandardTextFieldView(title: "Location (optional)", text: $location)
                    StandardTextFieldView(title: "Trading Style (optional)", text: $tradingStyle)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio (optional)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.horizontal, 24)

                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppColors.unhighlightedTextBoxBackground.opacity(0.75))
                            .foregroundColor(AppColors.whiteText)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trading Interests")
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 20)

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
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Social Links (optional)")
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 20)

                        StandardTextFieldView(title: "X / Twitter username", text: $twitterHandle)
                        StandardTextFieldView(title: "Discord username", text: $discordHandle)
                        StandardTextFieldView(title: "Telegram username", text: $telegramHandle)
                        StandardTextFieldView(title: "TradingView username", text: $tradingViewHandle)
                        StandardTextFieldView(title: "YouTube channel", text: $youtubeHandle)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if !path.isEmpty { path.removeLast() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(AppColors.unhighlightedButtonBackground)
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Divider()
                    .frame(height: 1)
                    .background(Color.gray.opacity(0.3))

                HStack(spacing: 10) {
                    Button {
                        rlAppState.completeOnboardingAndEnterApp()
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
        }
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

            let request = RLUserProfileUpdateRequest(
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                tradingStyle: tradingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tradingStyle.trimmingCharacters(in: .whitespacesAndNewlines),
                socialLinks: links.isEmpty ? nil : links,
                tradingInterests: selected.isEmpty ? nil : selected
            )
            _ = try await rlAppState.updateCurrentUserProfile(request)
        } catch {
            // Error surfaced by RLAppState
        }

        rlAppState.completeOnboardingAndEnterApp()
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
                            .fill(Color.green)
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
