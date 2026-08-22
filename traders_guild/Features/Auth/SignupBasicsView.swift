//
//  SignupBasicsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

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
                        Text("Step 3 of 5")
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
        .platformNavigationBarBackground(AppColors.gradientBackgroundDark)
        .platformNavigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .platformLeading) {
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
                        path.append(.profile)
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
                        path.append(.profile)
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
