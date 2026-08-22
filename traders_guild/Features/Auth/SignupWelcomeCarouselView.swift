import SwiftUI

private struct SignupWelcomeStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let accentColor: Color
}

struct SignupWelcomeCarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStepIndex: Int = 0

    private let steps: [SignupWelcomeStep] = [
        SignupWelcomeStep(
            icon: "star.bubble.fill",
            title: "Place Markers On The Chart",
            message: "Share setups, analysis, questions, alerts, and news directly on symbols so your ideas stay attached to the market context.",
            accentColor: AppColors.signupInterestBlue
        ),
        SignupWelcomeStep(
            icon: "person.3.fill",
            title: "Learn Inside Your Guild",
            message: "Guilds bring together chatrooms, announcements, events, and member activity so discussion stays focused and high signal.",
            accentColor: AppColors.accentColor
        ),
        SignupWelcomeStep(
            icon: "chart.bar.doc.horizontal.fill",
            title: "Build Reputation Over Time",
            message: "Helpful participation and tracked marker outcomes contribute to your reputation and accuracy so strong contributors stand out.",
            accentColor: AppColors.signupInterestGreen
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Getting Started")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)

                Spacer()

                Button("Skip") {
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.greyText)
            }

            TabView(selection: $currentStepIndex) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(step.accentColor.opacity(0.16))
                                .frame(width: 78, height: 78)
                            Image(systemName: step.icon)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(step.accentColor)
                        }
                        .padding(.top, 8)

                        Text(step.title)
                            .font(.title3.bold())
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)

                        Text(step.message)
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                    }
                    .padding(.horizontal, 12)
                    .tag(index)
                }
            }
            .platformPageTabViewStyle()
            .frame(height: 280)

            HStack(spacing: 10) {
                if currentStepIndex > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStepIndex -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.greyText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.symbolDetailCardFill)
                            )
                    }
                }

                Button {
                    if currentStepIndex == steps.count - 1 {
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStepIndex += 1
                        }
                    }
                } label: {
                    Text(currentStepIndex == steps.count - 1 ? "Start Exploring" : "Next")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.gradientBackgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.whiteText)
                        )
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                AppColors.sheetBackground
                StaticPatternView()
            }
            .ignoresSafeArea()
        )
    }
}
