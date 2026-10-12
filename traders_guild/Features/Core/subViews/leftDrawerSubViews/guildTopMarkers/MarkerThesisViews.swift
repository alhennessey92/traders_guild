//
//  MarkerThesisViews.swift
//  traders_guild
//
//  The drawer's thesis pieces (owner, 12 Oct 2026): a debate card for the
//  Theses tab, and the reply rows the Live Feed tucks beneath the marker they
//  answer. Relationship colours and dashes are the chart's own
//  (`MarkerLinkRelationship`), so a reply reads the same here as on the chart.
//

import SwiftUI

// MARK: - Stance

/// How a thesis's replies divide, as one bar: supports, challenges, builds on.
struct MarkerStanceBar: View {
    let stance: MarkerThesisStance
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let parts = MarkerLinkRelationship.allCases.filter { stance.count($0) > 0 }
            let gap: CGFloat = 2
            let usable = max(0, proxy.size.width - gap * CGFloat(max(0, parts.count - 1)))
            HStack(spacing: gap) {
                ForEach(parts, id: \.self) { relationship in
                    Capsule()
                        .fill(relationship.accentColor)
                        .frame(width: usable * CGFloat(stance.count(relationship)) / CGFloat(max(1, stance.total)))
                }
            }
        }
        .frame(height: height)
        .background(Capsule().fill(AppColors.whiteText.opacity(0.06)))
        .accessibilityElement()
        .accessibilityLabel(MarkerStanceBar.summary(stance))
    }

    static func summary(_ stance: MarkerThesisStance) -> String {
        MarkerLinkRelationship.allCases.compactMap { relationship in
            let count = stance.count(relationship)
            return count > 0 ? "\(relationship.displayName) \(count)" : nil
        }.joined(separator: ", ")
    }
}

/// The bar's key: a coloured count per relationship present.
struct MarkerStanceLegend: View {
    let stance: MarkerThesisStance

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MarkerLinkRelationship.allCases.filter { stance.count($0) > 0 }, id: \.self) { relationship in
                HStack(spacing: 4) {
                    Image(systemName: relationship.icon)
                        .font(.system(size: 9, weight: .heavy))
                    Text("\(relationship.displayName) \(stance.count(relationship))")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(relationship.accentColor)
                .lineLimit(1)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Reply row

/// One reply, as the thread shows it: its relationship in its colour, its
/// author's face and what it says.
struct MarkerThesisReplyRow: View {
    let reply: RLMarkerActivityItemDTO
    /// Named when the reply answers someone other than the thread's head.
    var answering: String? = nil
    let onTap: () -> Void

    private var relationship: MarkerLinkRelationship? { reply.linkRelationshipKnown }

    private var text: String? {
        let candidates = [reply.title, reply.notePreview, reply.pollQuestion]
        return candidates.lazy.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .map { reply.intentEnum == .alert ? MarkerAlertSeverity.stripKnownPrefix(from: $0) : $0 }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                UnifiedMarkerBadge(
                    intent: reply.intentEnum,
                    alertSeverity: reply.alertSeverityEnum,
                    sizeToken: .small,
                    avatar: MarkerAvatarIdentity.forListItem(reply)
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let relationship {
                            Image(systemName: relationship.icon)
                                .font(.system(size: 8, weight: .heavy))
                                .accessibilityHidden(true)
                            Text(relationship.displayName)
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(answering.map { "@\(reply.authorUsername) → @\($0)" } ?? "@\(reply.authorUsername)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.listCardSecondaryText)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(reply.activityTimestampFormatted)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.greyText.opacity(0.9))
                            .lineLimit(1)
                    }
                    .foregroundColor(relationship?.accentColor ?? AppColors.listCardSecondaryText)
                    if let text {
                        Text(text)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primaryForeground)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this reply on the chart")
    }
}

/// A thread's spine: the replies beneath their marker, each joined by a short
/// line in its relationship's colour and dash.
struct MarkerThreadReplies: View {
    let replies: [RLMarkerActivityItemDTO]
    /// Who each reply answers, by marker id, where it is not the head.
    var answering: [UUID: String] = [:]
    /// Each reply's distance from the head; a reply to a reply steps in.
    var depths: [UUID: Int] = [:]
    let onTapReply: (RLMarkerActivityItemDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(replies) { reply in
                HStack(alignment: .top, spacing: 8) {
                    MarkerThreadTether(relationship: reply.linkRelationshipKnown)
                        .frame(width: 14)
                    MarkerThesisReplyRow(reply: reply, answering: answering[reply.id]) { onTapReply(reply) }
                }
                .padding(.leading, CGFloat(min(max((depths[reply.id] ?? 1) - 1, 0), 2)) * 16)
            }
        }
    }
}

/// The elbow joining a reply to the thread: down from the marker above, then
/// across to the reply, in the relationship's colour and dash.
struct MarkerThreadTether: View {
    let relationship: MarkerLinkRelationship?

    var body: some View {
        Canvas { context, size in
            let x = size.width * 0.35
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: 18))
            path.addQuadCurve(to: CGPoint(x: size.width, y: 24), control: CGPoint(x: x, y: 24))
            context.stroke(
                path,
                with: .color(relationship?.accentColor ?? AppColors.greyText),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: relationship?.dashPattern ?? [3, 2])
            )
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

/// Above a reply whose marker is not in the feed: what it answers.
struct MarkerReplyContextLine: View {
    let reply: RLMarkerActivityItemDTO
    var onOpenParent: (() -> Void)? = nil

    private var parentLabel: String? {
        guard let preview = reply.parentPreview, !preview.isUnavailable else { return nil }
        let author = preview.authorUsername.map { "@\($0)" } ?? "a marker"
        let title = [preview.title, preview.note].lazy.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return title.map { "\(author) · \($0)" } ?? author
    }

    var body: some View {
        if let relationship = reply.linkRelationshipKnown {
            Button { onOpenParent?() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .accessibilityHidden(true)
                    Text(relationship.displayName)
                        .font(.system(size: 11, weight: .bold))
                    Text(parentLabel ?? "a marker that is no longer available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.listCardSecondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundColor(relationship.accentColor)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onOpenParent == nil)
            .accessibilityElement(children: .combine)
            .accessibilityHint(onOpenParent == nil ? "" : "Opens the marker it answers")
        }
    }
}

// MARK: - Thesis card

/// A debate at a glance: the marker, how the guild has answered it, and the
/// latest replies.
struct MarkerThesisCard: View {
    let thesis: MarkerThesis
    /// How many of the newest replies to show in the card.
    var replyPreviewLimit = 2
    let onOpen: () -> Void
    let onOpenReply: (RLMarkerActivityItemDTO) -> Void

    private struct HeadDisplay {
        let intent: RLMarkerIntent
        let alertSeverity: MarkerAlertSeverity?
        let avatar: MarkerAvatarIdentity
        let author: String
        let ticker: String
        let timeframe: String
        let title: String?
        let note: String?
    }

    private var head: HeadDisplay {
        switch thesis.head {
        case .item(let item):
            let note = item.notePreview.map {
                item.intentEnum == .alert ? MarkerAlertSeverity.stripKnownPrefix(from: $0) : $0
            }
            return HeadDisplay(
                intent: item.intentEnum, alertSeverity: item.alertSeverityEnum,
                avatar: MarkerAvatarIdentity.forListItem(item), author: item.authorUsername,
                ticker: item.symbolTicker, timeframe: item.timeframe,
                title: item.title ?? item.pollQuestion, note: note
            )
        case .preview(let preview):
            let intent = preview.intent.flatMap(RLMarkerIntent.init(rawValue:)) ?? .analysis
            let username = preview.authorUsername ?? preview.authorDisplayName
            var avatar = MarkerAvatarIdentity(
                url: preview.authorAvatarUrl,
                initials: username.map { String($0.prefix(2)).uppercased() },
                authorId: preview.authorId
            )
            if !MarkerAvatarPresentation.live.contains(intent) { avatar = .none }
            return HeadDisplay(
                intent: intent, alertSeverity: nil, avatar: avatar, author: username ?? "member",
                ticker: preview.ticker ?? "", timeframe: preview.timeframe ?? "",
                title: preview.title, note: preview.note
            )
        }
    }

    private var headline: String {
        let display = head
        return [display.title, display.note].lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? display.intent.displayName
    }

    private var bodyText: String? {
        let display = head
        guard let title = display.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
              let note = display.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty,
              note != title else { return nil }
        return note
    }

    private var lastActivityText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: thesis.lastActivity, relativeTo: Date())
    }

    private var replyFaces: [RLMarkerActivityItemDTO] {
        var seen = Set<UUID>()
        return thesis.replies.filter { seen.insert($0.authorId).inserted }.prefix(4).map { $0 }
    }

    var body: some View {
        let display = head
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        UnifiedMarkerBadge(intent: display.intent, alertSeverity: display.alertSeverity,
                                           sizeToken: .large, avatar: display.avatar)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(headline)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.primaryForeground)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(["@\(display.author)", display.intent.displayName, display.ticker, display.timeframe]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.listCardSecondaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(lastActivityText)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.greyText.opacity(0.9))
                            .lineLimit(1)
                    }
                    if let bodyText {
                        Text(bodyText)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primaryForeground.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if thesis.stance.total > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            MarkerStanceBar(stance: thesis.stance)
                            MarkerStanceLegend(stance: thesis.stance)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(headline), by \(display.author). \(MarkerStanceBar.summary(thesis.stance))")
            .accessibilityHint("Opens the thesis on the chart")

            if !thesis.replies.isEmpty {
                MarkerThreadReplies(replies: Array(thesis.replies.prefix(replyPreviewLimit)), onTapReply: onOpenReply)
            }

            footer
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.markerListCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                )
        )
    }

    private var footer: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(replyFaces) { reply in
                        UnifiedMarkerBadge(intent: reply.intentEnum, alertSeverity: reply.alertSeverityEnum,
                                           sizeToken: .tiny, avatar: MarkerAvatarIdentity.forListItem(reply))
                    }
                }
                .accessibilityHidden(true)
                Text(thesis.replyCount == 1 ? "1 reply" : "\(thesis.replyCount) replies")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.listCardSecondaryText)
                Spacer(minLength: 4)
                Text("Open thesis")
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .accessibilityHidden(true)
            }
            .foregroundColor(AppColors.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Live Feed thread

/// A Live Feed entry: the marker as the feed always showed it, with the
/// replies the feed also holds joined beneath it.
struct MarkerFeedClusterView<Item: View>: View {
    let cluster: MarkerFeedCluster
    /// The marker's usual list item.
    @ViewBuilder let item: (RLMarkerActivityItemDTO) -> Item
    let onTapReply: (RLMarkerActivityItemDTO) -> Void
    var onOpenParent: ((RLMarkerActivityItemDTO) -> Void)? = nil

    /// Replies that answer another reply name whom they answer.
    private var answering: [UUID: String] {
        let byId = Dictionary(([cluster.head] + cluster.replies).map { ($0.id, $0.authorUsername) },
                              uniquingKeysWith: { first, _ in first })
        var result: [UUID: String] = [:]
        for reply in cluster.replies where reply.parentMarkerId != cluster.head.id {
            if let parent = reply.parentMarkerId, let name = byId[parent] { result[reply.id] = name }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cluster.head.parentMarkerId != nil {
                MarkerReplyContextLine(reply: cluster.head,
                                       onOpenParent: onOpenParent.map { open in { open(cluster.head) } })
            }
            item(cluster.head)
            if !cluster.replies.isEmpty {
                MarkerThreadReplies(replies: cluster.replies, answering: answering, depths: cluster.depths,
                                    onTapReply: onTapReply)
                    .padding(.leading, 18)
                    .padding(.trailing, 6)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Lists

/// The Theses tab's list.
struct MarkerThesesList: View {
    let theses: [MarkerThesis]
    let onOpen: (MarkerThesis) -> Void
    let onOpenReply: (RLMarkerActivityItemDTO) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(theses) { thesis in
                MarkerThesisCard(thesis: thesis, onOpen: { onOpen(thesis) }, onOpenReply: onOpenReply)
            }
        }
    }
}

/// The Live Feed, threaded: each entry the marker's usual list item with its
/// replies beneath.
struct MarkerThreadedFeed<Item: View>: View {
    let markers: [RLMarkerActivityItemDTO]
    @ViewBuilder let item: (RLMarkerActivityItemDTO) -> Item
    let onTapReply: (RLMarkerActivityItemDTO) -> Void
    var onOpenParent: ((RLMarkerActivityItemDTO) -> Void)? = nil

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(MarkerThesisFeed.clusters(from: markers)) { cluster in
                MarkerFeedClusterView(cluster: cluster, item: item, onTapReply: onTapReply, onOpenParent: onOpenParent)
            }
        }
    }
}
