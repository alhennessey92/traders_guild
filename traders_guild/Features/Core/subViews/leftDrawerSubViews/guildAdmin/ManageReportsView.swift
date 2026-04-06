//
//  ManageReportsView.swift
//  traders_guild
//
//  Admin/Moderator Panel - Manage Reports View
//  Moderators can view reports, Admins can resolve/dismiss
//

import SwiftUI

// MARK: - Report Filters

enum ReportStatusFilter: String, CaseIterable, UnifiedTabItem {
    case all = "All"
    case pending = "Pending"
    case resolved = "Resolved"
    case dismissed = "Dismissed"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .pending: return "clock.fill"
        case .resolved: return "checkmark.circle.fill"
        case .dismissed: return "xmark.circle.fill"
        }
    }

    var apiValue: String? {
        self == .all ? nil : self.rawValue.lowercased()
    }
}

enum ContentTypeFilter: String, CaseIterable, UnifiedTabItem {
    case all = "All"
    case messages = "Chat Messages"
    case dmMessages = "DMs"
    case chartChat = "Chart Chat"
    case markers = "Markers"
    case users = "Users"

    var title: String { tabLabel }

    /// Compact label for tab bar to avoid wrapping
    var tabLabel: String {
        switch self {
        case .all: return "All"
        case .messages: return "Chat"
        case .dmMessages: return "DMs"
        case .chartChat: return "Chart"
        case .markers: return "Markers"
        case .users: return "Users"
        }
    }

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
    @Binding var bottomSheetContent: BottomSheetContent?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    @State private var reports: [RLContentReportDTO] = []
    @State private var isLoading: Bool = true
    @State private var totalCount: Int = 0
    @State private var pendingCount: Int = 0

    // Filters
    @State private var selectedStatus: ReportStatusFilter = .pending
    @State private var selectedContentType: ContentTypeFilter = .all

    // Resolution
    @State private var selectedReport: RLContentReportDTO? = nil
    @State private var resolutionNote: String = ""
    @State private var isProcessing: Bool = false
    @State private var memberActionUserId: UUID? = nil  // for loading state on Suspend/Kick/Ban

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
                    .padding(.bottom, 12)
                    .adminSheetChrome(edge: .top)

                // Status Filter
                statusFilterBar
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(AppColors.sheetBackground.opacity(0.98))

                // Content Type Filter
                contentTypeFilterBar
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(AppColors.sheetBackground.opacity(0.98))

                Divider()

                // Content
                contentView
            }

            // Dismiss button
            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminSheetBackground())
        .onAppear {
            loadReports()
        }
        .onChange(of: selectedStatus) { _ in
            loadReports()
        }
        .onChange(of: selectedContentType) { _ in
            loadReports()
        }
        .sheet(item: $selectedReport) { report in
            resolveSheet(for: report)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        AdminSheetHeader(
            icon: "flag.fill",
            iconColor: .red,
            title: "Manage Reports",
            subtitle: canAdmin ? "Review & resolve reports" : "View reported content",
            trailing: pendingCount > 0 ? AnyView(
                Text("\(pendingCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.orange))
            ) : nil
        )
    }

    // MARK: - Status Filter Bar

    private var statusFilterBar: some View {
        UnifiedTabBar(
            selectedTab: $selectedStatus,
            size: .compact,
            theme: .subTab,
            countForTab: { tab in
                tab == .pending ? pendingCount : 0
            },
            spacing: 6
        )
        .padding(.horizontal)
    }

    // MARK: - Content Type Filter Bar

    private var contentTypeFilterBar: some View {
        UnifiedTabBar(
            selectedTab: $selectedContentType,
            size: .compact,
            theme: .deepSubTab,
            spacing: 6
        )
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reports.isEmpty {
            VStack {
                Spacer()
                emptyState
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(reports) { report in
                        reportCard(report: report)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        UnifiedEmptyState(
            icon: "checkmark.shield.fill",
            title: "No Reports",
            subtitle: emptyStateSubtitle
        )
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
            resolutionNote = ""
            selectedReport = report
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
                        .foregroundColor(AppColors.greyText)
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
                            .foregroundColor(AppColors.whiteText)

                        // Reason badge
                        Text(report.reasonDisplay)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.onAccentForeground)
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
                            .foregroundColor(AppColors.greyText)
                    }

                    // Content snippet or reporter details (if any)
                    if let snippet = report.contentSnippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.8))
                            .lineLimit(2)
                    }
                    if let details = report.details, !details.isEmpty {
                        Text(details)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.8))
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
                                    .foregroundColor(AppColors.greyText)
                            }
                        }
                        if let note = report.resolutionNote, !note.isEmpty {
                            Text("Note: \(note)")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    // Timestamp
                    Text(report.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.6))
                }

                // Chevron for all reports
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 0.8)
                )
        )
    }

    // MARK: - Report Detail Sheet

    @ViewBuilder
    private func resolveSheet(for report: RLContentReportDTO) -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Status Banner ──
                    HStack(spacing: 8) {
                        Circle()
                            .fill(report.statusColor)
                            .frame(width: 10, height: 10)
                        Text(report.status.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(report.statusColor)
                        Spacer()
                        Text(report.reasonDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.onAccentForeground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(reasonColor(for: report.reason)))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(report.statusColor.opacity(0.1))
                    )

                    // ── Reported Content Info ──
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Reported Content", systemImage: report.contentTypeIcon)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            infoRow(label: "Type", value: report.contentTypeDisplay)
                            infoRow(label: "Content ID", value: report.contentId.uuidString.prefix(8).uppercased() + "...")
                            if let snippet = report.contentSnippet, !snippet.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Preview")
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                    Text(snippet)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.whiteText)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.whiteText.opacity(0.05))
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.symbolSheetGroupedPanelFill)
                    )

                    // ── Reported User (offending user) ──
                    if let reportedUserId = report.reportedUserId {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Reported User", systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let member = leftDrawerViewModel.guildMembers.first(where: { $0.userId == reportedUserId }) {
                                HStack {
                                    Text("@\(member.username)")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.whiteText)
                                    Spacer()
                                    Button("View profile") {
                                        selectedReport = nil
                                        bottomSheetContent = .guildMemberRL(member)
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.whiteText.opacity(0.05))
                                )
                            } else {
                                infoRow(label: "User ID", value: reportedUserId.uuidString.prefix(8).uppercased() + "...")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.symbolSheetGroupedPanelFill)
                        )
                    }

                    // ── Reporter Details ──
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Report Details", systemImage: "flag.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            if let reporterName = report.reporterDisplayName ?? report.reporterUsername {
                                infoRow(label: "Reported by", value: reporterName)
                            }
                            infoRow(label: "Reason", value: report.reasonDisplay)

                            if let details = report.details, !details.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Additional Details")
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                    Text(details)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.whiteText)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.whiteText.opacity(0.05))
                                        )
                                }
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("Reported \(report.createdAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.symbolSheetGroupedPanelFill)
                    )

                    // ── Resolution Info (for already resolved/dismissed reports) ──
                    if report.isResolved || report.isDismissed {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                report.isResolved ? "Resolved" : "Dismissed",
                                systemImage: report.isResolved ? "checkmark.seal.fill" : "xmark.seal.fill"
                            )
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(report.statusColor)

                            VStack(alignment: .leading, spacing: 6) {
                                if let reviewer = report.reviewerDisplayName {
                                    infoRow(label: "Reviewed by", value: reviewer)
                                }
                                if let reviewedAt = report.reviewedAt {
                                    HStack(spacing: 4) {
                                        Text("When")
                                            .font(.caption)
                                            .foregroundColor(AppColors.greyText)
                                            .frame(width: 80, alignment: .leading)
                                        Text(reviewedAt, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(AppColors.whiteText)
                                        Text("ago")
                                            .font(.caption)
                                            .foregroundColor(AppColors.whiteText)
                                    }
                                }
                                if let note = report.resolutionNote, !note.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Resolution Note")
                                            .font(.caption)
                                            .foregroundColor(AppColors.greyText)
                                        Text(note)
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.whiteText)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(AppColors.whiteText.opacity(0.05))
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(report.statusColor.opacity(0.08))
                        )
                    }

                    // ── Take action on reported user (pending + admin + has reported user) ──
                    if report.isPending && canAdmin, let reportedUserId = report.reportedUserId {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Take Action on User", systemImage: "person.crop.circle.badge.exclamationmark")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            let busy = memberActionUserId == reportedUserId
                            HStack(spacing: 8) {
                                Button(action: { suspendReportedUser(report: report, userId: reportedUserId) }) {
                                    HStack(spacing: 4) {
                                        if busy { ProgressView().scaleEffect(0.7).tint(AppColors.onAccentForeground) }
                                        Image(systemName: "pause.circle.fill")
                                        Text("Suspend")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                .disabled(isProcessing || busy)
                                Button(action: { kickReportedUser(report: report, userId: reportedUserId) }) {
                                    HStack(spacing: 4) {
                                        if busy { ProgressView().scaleEffect(0.7).tint(AppColors.onAccentForeground) }
                                        Image(systemName: "person.fill.xmark")
                                        Text("Kick")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                .disabled(isProcessing || busy)
                                Button(action: { banReportedUser(report: report, userId: reportedUserId) }) {
                                    HStack(spacing: 4) {
                                        if busy { ProgressView().scaleEffect(0.7).tint(AppColors.onAccentForeground) }
                                        Image(systemName: "nosign")
                                        Text("Ban")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(isProcessing || busy)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.symbolSheetGroupedPanelFill)
                        )
                    }

                    // ── Admin Actions (only for pending reports + admin/owner) ──
                    if report.isPending && canAdmin {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Resolve Report", systemImage: "gavel.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Resolution note
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Resolution Note (Optional)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)

                                TextField("Add a note about your decision...", text: $resolutionNote, axis: .vertical)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.whiteText)
                                    .lineLimit(3...5)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.9))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(AppColors.surfaceWhite15, lineWidth: 1)
                                            )
                                    )
                            }

                            // Action buttons
                            HStack(spacing: 12) {
                                // Resolve button
                                Button(action: { resolveReport(report, action: "resolved") }) {
                                    HStack(spacing: 6) {
                                        if isProcessing {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .tint(AppColors.onAccentForeground)
                                        }
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Resolve")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .disabled(isProcessing)

                                // Dismiss button
                                Button(action: { resolveReport(report, action: "dismissed") }) {
                                    HStack(spacing: 6) {
                                        if isProcessing {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Dismiss")
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.symbolSheetGroupedPanelFill)
                        )
                    } else if report.isPending && !canAdmin {
                        // Moderator viewing pending report — info only
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Only admins and owners can resolve or dismiss reports.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.statusInfo08)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Report Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        selectedReport = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Info Row Helper

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(AppColors.whiteText)
        }
    }

    // MARK: - Helpers

    private func reasonColor(for reason: String) -> Color {
        switch reason {
        case "spam": return .blue
        case "harassment": return .red
        case "hate_speech": return .purple
        case "inappropriate": return .orange
        case "misinformation": return AppColors.statusHighlight80
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
                selectedReport = nil
                resolutionNote = ""
                loadReports()
            } catch {
                // Error shown by appState
            }
            isProcessing = false
        }
    }

    private func suspendReportedUser(report: RLContentReportDTO, userId: UUID) {
        memberActionUserId = userId
        Task {
            do {
                try await rlAppState.suspendMember(userId: userId, durationMinutes: 60, reason: "Report #\(report.id.uuidString.prefix(8))")
                await resolveReportAfterMemberAction(report: report, actionNote: "User suspended (1 hour)")
            } catch {
                // Error shown by appState
            }
            memberActionUserId = nil
        }
    }

    private func kickReportedUser(report: RLContentReportDTO, userId: UUID) {
        memberActionUserId = userId
        Task {
            do {
                try await rlAppState.kickMember(userId: userId)
                await resolveReportAfterMemberAction(report: report, actionNote: "User kicked")
            } catch {
                // Error shown by appState
            }
            memberActionUserId = nil
        }
    }

    private func banReportedUser(report: RLContentReportDTO, userId: UUID) {
        memberActionUserId = userId
        Task {
            do {
                _ = try await rlAppState.banMember(userId: userId, reason: resolutionNote.isEmpty ? "Report" : resolutionNote)
                await resolveReportAfterMemberAction(report: report, actionNote: "User banned")
            } catch {
                // Error shown by appState
            }
            memberActionUserId = nil
        }
    }

    private func resolveReportAfterMemberAction(report: RLContentReportDTO, actionNote: String) async {
        do {
            let _ = try await rlAppState.resolveReport(reportId: report.id, action: "resolved", note: actionNote)
            await MainActor.run {
                selectedReport = nil
                resolutionNote = ""
                loadReports()
            }
        } catch {
            // Optional: report stays pending
        }
    }
}
