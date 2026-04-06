//
//  AppleProfileCompletionView.swift
//  traders_guild
//
//  Collects required profile fields (display name, date of birth) for new
//  Apple Sign In users before continuing into the shared onboarding pipeline.
//

import SwiftUI

struct AppleProfileCompletionView: View {
    @Binding var data: RLSignupData
    @Binding var path: [RLSignupStep]
    @EnvironmentObject var rlAppState: RLAppState

    @State private var name: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var hasSetDOB: Bool = false

    private var normalizedName: String {
        RLAuthValidator.trimmed(name)
    }

    private var isFormValid: Bool {
        RLAuthValidator.isValidDisplayName(normalizedName) && hasSetDOB
    }

    private let minimumAge: Int = 13
    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -minimumAge, to: Date()) ?? Date()
    }

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack {
                    Text("Step 1 of 6")
                        .font(AppFonts.smallNotice())
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    HStack(spacing: 6) {
                        Capsule().fill(AppColors.whiteText).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                        Capsule().fill(AppColors.whiteText.opacity(0.25)).frame(height: 5)
                    }
                    .padding(.horizontal, 20)

                    Text("Complete your profile")
                        .font(.largeTitle.bold())
                        .foregroundColor(AppColors.whiteText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 6)
                        .padding(.leading, 20)

                    Text("We just need a few details to get you started.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    StandardTextFieldView(title: "Display name", text: $name)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.horizontal, 24)

                        DatePicker(
                            "Date of Birth",
                            selection: $dateOfBirth,
                            in: ...maximumDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(ThemeManager.shared.currentTheme.colorScheme)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .onChange(of: dateOfBirth) { _, _ in
                            hasSetDOB = true
                            dismissKeyboard()
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissKeyboard()
                            }
                        )
                    }
                    .padding(.bottom, 16)

                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTapAndDragBackground()
            .onAppear {
                if name.isEmpty {
                    name = data.name
                }
                if let dob = data.dateOfBirth {
                    dateOfBirth = dob
                    hasSetDOB = true
                }
            }
            .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
            }
        }
        .keyboardPinnedBottomInset {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .background(AppColors.surfaceGray30)

                StandardActionButtonFullWidth(
                    title: "Continue",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark
                ) {
                    data.name = normalizedName
                    data.dateOfBirth = dateOfBirth
                    path.append(.username)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .background(AppColors.sheetBackground)
        }
    }
}
