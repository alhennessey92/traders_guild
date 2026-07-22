//
//  EmbeddedMarkerDetailView.swift
//  traders_guild
//
//  Embedded version of MarkerDetailView for the bottom sheet takeover.
//  Reuses MarkerDetailHeaderView and MarkerInfoContent.
//  No NavigationStack or dismiss — uses onClose closure.
//

import SwiftUI
import Combine

struct EmbeddedMarkerDetailView: View {
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @ObservedObject var markerManager: MarkerManager

    let marker: ChartMarkerUI
    let onClose: () -> Void

    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var comments: [RLMarkerCommentDTO] = []
    @State private var showDeleteMarkerConfirmation: Bool = false
    @State private var showReportReasonSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var selectedAuthorProfileMember: RLGuildMemberDTO? = nil
    @State private var authorProfileDetent: PresentationDetent = .fraction(0.6)

    init(marker: ChartMarkerUI, markerManager: MarkerManager, onClose: @escaping () -> Void) {
        self.marker = marker
        self.markerManager = markerManager
        self.onClose = onClose

        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
        _likeCount = State(initialValue: marker.likeCount)
        _comments = State(initialValue: marker.comments)
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkerDetailHeaderView(
                marker: marker,
                isLiked: isLiked,
                likeCount: likeCount,
                commentCount: comments.count,
                isOwner: marker.isCurrentUserMarker,
                showsActionRow: true,
                onAuthorTap: {
                    selectedAuthorProfileMember = marker.author
                },
                onLike: handleLike,
                onShare: handleShare,
                onReport: { showReportReasonSheet = true },
                onDelete: { showDeleteMarkerConfirmation = true }
            )

            ScrollView(.vertical, showsIndicators: false) {
                MarkerInfoContent(marker: marker)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert("Delete Marker", isPresented: $showDeleteMarkerConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                handleDelete()
            }
        } message: {
            Text("Are you sure you want to delete this marker? This action cannot be undone.")
        }
        .sheet(isPresented: $showReportReasonSheet) {
            ReportReasonSheet(
                title: "Why are you reporting this marker?",
                includeScam: false,
                onReasonSelected: { reason in
                    handleReport(reason: reason)
                    showReportReasonSheet = false
                },
                onCancel: { showReportReasonSheet = false }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            MarkerShareSheet(marker: marker)
                .environmentObject(rlAppState)
        }
        .sheet(item: $selectedAuthorProfileMember) { member in
            if member.userId == rlAppState.currentUser?.id {
                UserProfileDetailView(selectedDetent: $authorProfileDetent)
                    .environmentObject(rlAppState)
                    .environmentObject(leftDrawerViewModel)
            } else {
                GuildUserDetailViewRL(member: member)
                    .environmentObject(rlAppState)
            }
        }
        .onReceive(markerManager.$markers) { updatedMarkers in
            guard let updated = updatedMarkers.first(where: { $0.id == marker.id }) else { return }
            if updated.comments != comments {
                comments = updated.comments
            }
            if updated.likeCount != likeCount {
                likeCount = updated.likeCount
            }
            if updated.isLikedByCurrentUser != isLiked {
                isLiked = updated.isLikedByCurrentUser
            }
        }
        .onAppear {
            syncStateWithLatestMarker()
        }
    }

    // MARK: - Actions

    private func handleLike() {
        HapticFeedback.light.trigger()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }

        Task {
            await markerManager.toggleLike(markerId: marker.id)
        }
    }

    private func handleShare() {
        guard MarkerShare.canShareWithinGuild(visibility: marker.visibility) else { return }
        HapticFeedback.medium.trigger()
        showShareSheet = true
    }

    private func handleReport(reason: String) {
        HapticFeedback.medium.trigger()
        Task {
            do {
                _ = try await rlAppState.reportMarker(
                    guildId: marker.guildId,
                    markerId: marker.id,
                    reason: reason
                )
            } catch {
                return
            }
        }
    }

    private func handleDelete() {
        HapticFeedback.warning.trigger()
        Task {
            await markerManager.deleteMarker(id: marker.id)
            rlAppState.showSuccess("Marker deleted")
            onClose()
        }
    }

    private func syncStateWithLatestMarker() {
        guard let updated = markerManager.markers.first(where: { $0.id == marker.id }) else { return }
        comments = updated.comments
        likeCount = updated.likeCount
        isLiked = updated.isLikedByCurrentUser
    }
}
