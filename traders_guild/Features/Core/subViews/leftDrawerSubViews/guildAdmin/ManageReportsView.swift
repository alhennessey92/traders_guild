//
//  ManageReportsView.swift
//  traders_guild
//
//  Admin/Moderator Panel - Manage Reports View
//  Moderators can view reports, Admins can resolve/dismiss
//

import SwiftUI

// MARK: - Report Filters

enum ReportStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case resolved = "Resolved"
    case dismissed = "Dismissed"

    var apiValue: String? {
        self == .all ? nil : self.rawValue.lowercased()
    }
}

enum ContentTypeFilter: String, CaseIterable {
    case all = "All"
    case messages = "Chat Messages"
    case dmMessages = "DMs"
    case chartChat = "Chart Chat"
    case markers = "Markers"
    case users = "Users"

    var apiValue: String? {
        switch self {
        case .all: return nil
        case .messages: return "chatroom_message"
        case .dmMessages: return "dm_message"
        case .chartChat: return "chart_chat_message"
        case .markers: return "chart_marker"
        case .users: return "user"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .messages: return "bubble.left.fill"
        case .dmMessages: return "envelope.fill"
        case .chartChat: return "chart.line.uptrend.xyaxis"
        case .markers: return "mappin.circle.fill"
        case .users: return "person.fill"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - MANAGE REPORTS VIEW
// MARK: - ================================================================================================

struct ManageReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var reports: [RLContentReportDTO] = []
    @State private var isLoading: Bool = true
    @State private var totalCount: Int = 0
    @State private var pendingCount: Int = 0

    // Filters
    @State private var selectedStatus: ReportStatusFilter = .pending
    @State private var selectedContentType: ContentTypeFilter = .all

    // Resolution
    @State private var selectedReport: RLContentReportDTO? = nil
    @State private var showResolveSheet: Bool = false
    @State private var resolutionNote: String = ""
    @State private var isProcessing: Bool = false

    private var canAdmin: Bool {
        rlAppState.canAdmin
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal)
                    .padding(.top, 30)

                Divider()
                    .padding(.top, 12)

                // Status Filter
                statusFilterBar
                    .padding(.top, 8)

                // Content Type Filter
                contentTypeFilterBar
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Divider()

                // Content
                contentView
            }

            // Dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {
            loadReports()
        }
        .onChange(of: selectedStatus) { _ in
            loadReports()
        }
        .onChange(of: selectedContentType) { _ in
            loadReports()
        }
        .sheet(isPresented: $showResolveSheet) {
            if let report = selectedReport {
                resolveSheet(for: report)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            UnifiedIconBadge(
                icon: "flag.fill",
                color: .red,
                size: 44,
                iconSize: 20,
                backgroundOpacity: 0.2
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Manage Reports")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    // Pending badge
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange))
                    }
                }

                Text(canAdmin ? "Review & resolve reports" : "View reported content")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Status Filter Bar

    private var statusFilterBar: some View {
        HStack(spacing: 4) {
            ForEach(ReportStatusFilter.allCases, id: \.self) { filter in
                Button(action: { selectedStatus = filter }) {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                        // Show pending count badge
                        if filter == .pending && pendingCount > 0 {
                            Text("\(pendingCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.orange))
                        }
                    }
                    .foregroundColor(selectedStatus == filter ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedStatus == filter ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Content Type Filter Bar

    private var contentTypeFilterBar: some View {
        HStack(spacing: 6) {
            ForEach(ContentTypeFilter.allCases, id: \.self) { filter in
                Button(action: { selectedContentType = filter }) {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 10))
                        Text(filter.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedContentType == filter ? .white : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(selectedContentType == filter ? Color.accentColor.opacity(0.8) : AppColors.whiteText.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(selectedContentType == filter ? Color.clear : AppColors.whiteText.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading reports...")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if reports.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(reports) { report in
                        reportCard(report: report)
                        if report.id != reports.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No Reports")
                .font(.headline)
                .foregroundColor(.primary)
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateSubtitle: String {
        switch selectedStatus {
        case .all: return "There are no reports to display"
        case .pending: return "No pending reports to review"
        case .resolved: return "No resolved reports"
        case .dismissed: return "No dismissed reports"
        }
    }

    // MARK: - Report Card

    @ViewBuilder
    private func reportCard(report: RLContentReportDTO) -> some View {
        Button(action: {
            if report.isPending && canAdmin {
                selectedReport = report
                resolutionNote = ""
                showResolveSheet = true
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator + Content type icon
                VStack(spacing: 6) {
                    // Status dot
                    Circle()
                        .fill(report.statusColor)
                        .frame(width: 10, height: 10)

                    // Content type icon
                    Image(systemName: report.contentTypeIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 20)
                .padding(.top, 4)

                // Report info
                VStack(alignment: .leading, spacing: 6) {
                    // Top row: content type + reason
                    HStack(spacing: 6) {
                        Text(report.contentTypeDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        // Reason badge
                        Text(report.reasonDisplay)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(reasonColor(for: report.reason))
                            )

                        Spacer()

                        // Status label
                        Text(report.status.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(report.statusColor)
                    }

                    // Reporter
                    if let reporterName = report.reporterDisplayName ?? report.reporterUsername {
                        Text("Reported by \(reporterName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Details (if any)
                    if let details = report.details, !details.isEmpty {
                        Text(details)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                    }

                    // Resolution info (for resolved/dismissed)
                    if report.isResolved || report.isDismissed {
                        if let reviewer = report.reviewerDisplayName {
                            HStack(spacing: 4) {
                                Image(systemName: report.isResolved ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(report.statusColor)
                                Text("\(report.isResolved ? "Resolved" : "Dismissed") by \(reviewer)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let note = report.resolutionNote, !note.isEmpty {
                            Text("Note: \(note)")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    // Timestamp
                    Text(report.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }

                // Chevron for actionable reports
                if report.isPending && canAdmin {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!report.isPending || !canAdmin)
    }

    // MARK: - Resolve Sheet

    @ViewBuilder
    private func resolveSheet(for report: RLContentReportDTO) -> some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Report summary
                VStack(alignment: .leading, spacing: 12) {
                    // Content type & reason
                    HStack(spacing: 8) {
                        Image(systemName: report.contentTypeIcon)
                            .font(.title3)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.contentTypeDisplay)
                                .font(.headline)
                            Text("Reason: \(report.reasonDisplay)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    // Reporter
                    if let reporterName = report.reporterDisplayName ?? report.reporterUsername {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Reported by \(reporterName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Details
                    if let details = report.details, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Details")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(details)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Timestamp
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Reported \(report.createdAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

                // Resolution note
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution Note (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("Add a note about your decision...", text: $resolutionNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Resolve button
                    Button(action: { resolveReport(report, action: "resolved") }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Image(systemName: "checkmark.circle.fill")
                            Text("Resolve Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isProcessing)

                    // Dismiss button
                    Button(action: { resolveReport(report, action: "dismissed") }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "xmark.circle.fill")
                            Text("Dismiss Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .disabled(isProcessing)
                }
            }
            .padding()
            .navigationTitle("Review Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showResolveSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func reasonColor(for reason: String) -> Color {
        switch reason {
        case "spam": return .blue
        case "harassment": return .red
        case "hate_speech": return .purple
        case "inappropriate": return .orange
        case "misinformation": return .yellow.opacity(0.8)
        default: return .gray
        }
    }

    // MARK: - Actions

    private func loadReports() {
        isLoading = true
        Task {
            do {
                let result = try await rlAppState.fetchGuildReports(
                    status: selectedStatus.apiValue,
                    contentType: selectedContentType.apiValue
                )
                reports = result.reports
                totalCount = result.totalCount
                pendingCount = result.pendingCount
            } catch {
                // Error shown by appState
            }
            isLoading = false
        }
    }

    private func resolveReport(_ report: RLContentReportDTO, action: String) {
        isProcessing = true
        Task {
            do {
                let _ = try await rlAppState.resolveReport(
                    reportId: report.id,
                    action: action,
                    note: resolutionNote.isEmpty ? nil : resolutionNote.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                showResolveSheet = false
                resolutionNote = ""
                selectedReport = nil
                loadReports()
            } catch {
                // Error shown by appState
            }
            isProcessing = false
        }
    }
}
