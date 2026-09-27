import SwiftUI

struct BetaFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var category: String = "beta_feedback"
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var includeDeviceInfo = true
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    @FocusState private var isSubjectFocused: Bool

    private let categories = [
        SupportCategoryOption(id: "beta_feedback", title: "General Feedback", icon: "bubble.left.and.text.bubble.right.fill", subtitle: "Share impressions, ideas, and UX feedback"),
        SupportCategoryOption(id: "beta_bug", title: "Beta Bug", icon: "ant.fill", subtitle: "Something is broken, inconsistent, or failing"),
        SupportCategoryOption(id: "beta_issue", title: "Beta Issue", icon: "exclamationmark.triangle.fill", subtitle: "A rough edge, blocker, or confusing flow")
    ]

    private let subjectMinimum = 5
    private let messageMinimum = 20

    private var selectedCategoryOption: SupportCategoryOption {
        categories.first(where: { $0.id == category }) ?? categories[0]
    }

    private var isValid: Bool {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).count >= subjectMinimum &&
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= messageMinimum
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSubViewHeader(title: "Beta Feedback", onBack: { dismiss() })

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accentColor)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(AppColors.accentColor.opacity(0.16))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Help shape the beta")
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)
                                Text("Tell us what’s working, what feels off, or what’s blocking you.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }

                            Spacer()
                        }

                        Text("These submissions go straight into the existing support review queue, so include enough detail for us to understand what happened.")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    .padding(16)
                    .background(AppColors.insetPanelBackground)
                    .cornerRadius(14)
                    .padding(.top, 20)

                    SupportCategoryMenuField(
                        title: "Feedback Type",
                        selection: $category,
                        options: categories
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        SettingsTextField(
                            title: "Subject",
                            placeholder: "Short summary of the beta feedback",
                            text: $subject,
                            icon: "text.alignleft"
                        )
                        .focused($isSubjectFocused)

                        MinimumCharacterHint(
                            currentCount: subject.trimmingCharacters(in: .whitespacesAndNewlines).count,
                            minimum: subjectMinimum
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SupportMessageEditorCard(
                            title: "Details",
                            text: $message,
                            placeholder: "Explain what you saw, what you expected, and anything else that would help us investigate.",
                            characterLimit: 5000,
                            minHeight: 150
                        )

                        MinimumCharacterHint(
                            currentCount: message.trimmingCharacters(in: .whitespacesAndNewlines).count,
                            minimum: messageMinimum
                        )
                    }

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

                    Toggle(isOn: $includeDeviceInfo) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include device information")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)

                            Text("Helpful for reproduction and debugging")
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
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                StandardActionButtonFullWidth(
                    title: "Send Beta Feedback",
                    backgroundColor: isValid ? AppColors.accentColor : AppColors.greyText.opacity(0.5),
                    foregroundColor: .white,
                    isLoading: isSending,
                    isDisabled: !isValid || isSending,
                    action: submit
                )
                .padding(.horizontal, 25)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(AppColors.sheetBackground)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isSubjectFocused = false
            dismissKeyboard()
        }
        .alert("Feedback Sent", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thanks for helping us improve the beta.")
        }
    }

    private func submit() {
        guard isValid else { return }
        isSubjectFocused = false
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
                    errorMessage = "Failed to send feedback. Please try again."
                }
            }
        }
    }
}

struct MinimumCharacterHint: View {
    let currentCount: Int
    let minimum: Int

    private var isSatisfied: Bool { currentCount >= minimum }
    private var remaining: Int { max(minimum - currentCount, 0) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "circle")
                .font(.caption2)
                .foregroundColor(isSatisfied ? AppColors.statusPositive70 : AppColors.greyText)

            Text(isSatisfied
                 ? "Minimum \(minimum) characters reached"
                 : "\(remaining) more character\(remaining == 1 ? "" : "s") needed (min \(minimum))")
                .font(.caption2)
                .foregroundColor(isSatisfied ? AppColors.statusPositive70 : AppColors.greyText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.15), value: isSatisfied)
    }
}
