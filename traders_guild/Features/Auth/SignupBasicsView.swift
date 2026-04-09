//
//  SignupBasicsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

private struct SignupBasicFeature: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let detail: String
    let tintColor: Color
}

struct SignupBasicsView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var visibleCards: Set<UUID> = []

    private let featureCards: [SignupBasicFeature] = [
        SignupBasicFeature(
            title: "Guild Communities",
            icon: "shield.pattern.checkered",
            detail: "Guilds are your home base. Each one has focused chatrooms, events, announcements, and moderation controls so discussions stay relevant and useful.",
            tintColor: AppColors.accentColor
        ),
        SignupBasicFeature(
            title: "Chart Markers",
            icon: "star.bubble",
            detail: "Place directional ideas directly on the chart with entry, TP, and SL context. Members can react, discuss outcomes, and learn from real setups.",
            tintColor: AppColors.signupInterestBlue
        ),
        SignupBasicFeature(
            title: "Reputation and Accuracy",
            icon: "chart.bar.doc.horizontal",
            detail: "Your contribution to guild activity and your marker outcomes build long-term standing. Reputation and accuracy help highlight consistent traders.",
            tintColor: AppColors.signupInterestGreen
        ),
        SignupBasicFeature(
            title: "Safety First",
            icon: "checkmark.shield",
            detail: "Reporting, moderation, and role permissions help keep communities respectful, reduce spam, and protect high-signal conversation quality.",
            tintColor: AppColors.signupInterestPurple
        ),
    ]

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Step 3 of 6")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.greyText)

                        Text("How Traders Guild Works")
                            .font(.title.bold())
                            .foregroundColor(AppColors.whiteText)

                        Text("Welcome \(data.username). Here is a quick overview before personalization and guild selection.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack(spacing: 6) {
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What's Next")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "4.circle.fill")
                                    .foregroundColor(AppColors.accentColor)
                                    .font(.subheadline)
                                Text("Choose Interests")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                            }

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText.opacity(0.6))

                            HStack(spacing: 6) {
                                Image(systemName: "5.circle.fill")
                                    .foregroundColor(AppColors.accentColor)
                                    .font(.subheadline)
                                Text("Join a Guild")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                            }
                        }

                        Text("Profile details stay optional and editable later in settings.")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.gradientBackgroundDark.opacity(0.48))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        ForEach(Array(featureCards.enumerated()), id: \.element.id) { index, card in
                            SignupBasicFeatureCard(feature: card)
                                .opacity(visibleCards.contains(card.id) ? 1 : 0)
                                .offset(y: visibleCards.contains(card.id) ? 0 : 12)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.1),
                                    value: visibleCards.contains(card.id)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .onAppear {
                        for (index, card) in featureCards.enumerated() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(index) * 0.1) {
                                visibleCards.insert(card.id)
                            }
                        }
                    }

                    Spacer(minLength: 110)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !rlAppState.accountCreatedDuringOnboarding {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .interactiveDismissDisabled(rlAppState.accountCreatedDuringOnboarding)
        .keyboardPinnedBottomInset(background: AnyView(AuthKeyboardFooterChrome())) {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                HStack {
                    Spacer()
                    StandardActionButton(
                        title: "Continue",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        path.append(.interests)
                    }
                    .padding(.top)
                    .padding(.trailing)
                }
            }
            .background(Color.clear)
        }
    }
}

struct SignupInterestsView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var selectedInterests: Set<String> = []

    private let suggestedInterests: [RLTradingInterestItem] = RLTradingInterestsCatalog.allItems

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Step 4 of 6")
                            .font(AppFonts.smallNotice())
                            .foregroundColor(AppColors.greyText)

                        Text("Select Your Trading Interests")
                            .font(.title.bold())
                            .foregroundColor(AppColors.whiteText)

                        Text("These interests personalize your early feed and guild recommendations.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack(spacing: 6) {
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pick as many as you want")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(suggestedInterests) { interest in
                                SignupInterestChip(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest.name)
                                ) {
                                    if selectedInterests.contains(interest.name) {
                                        selectedInterests.remove(interest.name)
                                    } else {
                                        selectedInterests.insert(interest.name)
                                    }
                                    data.selectedInterests = suggestedInterests
                                        .map(\.name)
                                        .filter { selectedInterests.contains($0) }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.gradientBackgroundDark.opacity(0.48))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    Text("This is optional and can be changed later.")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 110)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !rlAppState.accountCreatedDuringOnboarding {
                    Button(action: {
                        if !path.isEmpty { path.removeLast() }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(AppColors.unhighlightedButtonBackground)
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .interactiveDismissDisabled(rlAppState.accountCreatedDuringOnboarding)
        .keyboardPinnedBottomInset(background: AnyView(AuthKeyboardFooterChrome())) {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                HStack(spacing: 10) {
                    Button {
                        data.selectedInterests = []
                        path.append(.guild)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                    }

                    Spacer()

                    StandardActionButton(
                        title: "Continue",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        data.selectedInterests = suggestedInterests
                            .map(\.name)
                            .filter { selectedInterests.contains($0) }
                        path.append(.guild)
                    }
                    .padding(.top)
                    .padding(.trailing)
                }
                .padding(.horizontal, 10)
            }
            .background(Color.clear)
        }
        .onAppear {
            if selectedInterests.isEmpty, !data.selectedInterests.isEmpty {
                selectedInterests = Set(data.selectedInterests)
            }
        }
    }
}

private struct SignupBasicFeatureCard: View {
    let feature: SignupBasicFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.tintColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: feature.icon)
                    .font(.title3)
                    .foregroundColor(feature.tintColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct SignupInterestChip: View {
    let interest: RLTradingInterestItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: interest.icon)
                    .font(.caption)
                Text(interest.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .foregroundColor(isSelected ? AppColors.gradientBackgroundDark : AppColors.whiteText)
            .background(
                Capsule().fill(isSelected ? AppColors.whiteText : AppColors.whiteText.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
