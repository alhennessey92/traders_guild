//
//  ReportReasonSheet.swift
//  traders_guild
//
//  Shared report reason picker used when reporting content or users
//  across chatrooms, DMs, chart chat, marker chat, markers, and user profiles.
//

import SwiftUI

// MARK: - Report Reason (matches backend ContentReportRequest.reason)

enum ReportReason: String, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case hateSpeech = "hate_speech"
    case inappropriate = "inappropriate"
    case misinformation = "misinformation"
    case scam = "scam"
    case other = "other"

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .hateSpeech: return "Hate Speech"
        case .inappropriate: return "Inappropriate"
        case .misinformation: return "Misinformation"
        case .scam: return "Scam or Fraud"
        case .other: return "Other"
        }
    }

    var apiValue: String { rawValue }
}

// MARK: - Report Reason Sheet

struct ReportReasonSheet: View {
    let title: String
    let message: String
    let includeScam: Bool  // true for reporting users
    let onReasonSelected: (String) -> Void
    let onCancel: () -> Void

    init(
        title: String = "Why are you reporting?",
        message: String = "Choose a reason so moderators can review appropriately.",
        includeScam: Bool = false,
        onReasonSelected: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.includeScam = includeScam
        self.onReasonSelected = onReasonSelected
        self.onCancel = onCancel
    }

    private var reasons: [ReportReason] {
        if includeScam {
            return ReportReason.allCases
        }
        return ReportReason.allCases.filter { $0 != .scam }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.sheetBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 10) {
                            ForEach(reasons, id: \.rawValue) { reason in
                                Button {
                                    onReasonSelected(reason.apiValue)
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(reason.displayName)
                                                .font(.body.weight(.semibold))
                                                .foregroundColor(AppColors.primaryForeground)
                                            Text("Send this reason to moderators for review.")
                                                .font(.caption)
                                                .foregroundColor(AppColors.greyText)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(AppColors.adaptiveAccessoryForeground)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppColors.panelFillEmphasis)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                                            )
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(AppColors.accentColor)
                }
            }
        }
    }
}
