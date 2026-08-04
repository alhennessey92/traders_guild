//
//  GuildCardView.swift
//  traders_guild
//
//  The single shared card for every guild render site.
//
//  Before this existed there were eight hand-rolled card shells for one entity —
//  switch row, discover row, pending row, two near-identical onboarding selection
//  rows, the profile guild card, the leaderboard guild row and the invite hub card.
//  Corner radius spanned {10, 12, 14, 16}, and the fill came from four unrelated
//  token families. That drift is what made the surface look unfinished.
//
//  The shell is `UnifiedContentCard` — the same container markers, announcements
//  and events already use — so guild cards inherit its press animation and stroke
//  instead of reinventing them. The footer strip mirrors `UnifiedAuthorFooter`.
//
//  Canonical values live in `docs/guild-flow-spec.md` §1. Change them there too.
//

import SwiftUI

// MARK: - Style

/// Which optional blocks a guild card renders. A single style enum rather than a
/// spread of booleans, so a call site stays one line and the shell cannot drift.
enum GuildCardStyle {
    /// Joined-guilds list: owner line, role + stats footer, current/chevron accessory.
    case switchRow
    /// Discover results: access pills, description, stats footer, chevron.
    case discover
    /// Awaiting approval: no footer, no tap, PENDING pill.
    case pending
    /// Onboarding guild selection: owner line, stats footer, check/circle accessory.
    case selection
    /// Dense contexts — profile guild list, leaderboard. No footer.
    case compact
}

/// Footer figures supplied by the caller rather than read off `guild`.
/// The leaderboard aggregates its own totals, which can legitimately differ
/// from the guild snapshot embedded in each of its rows.
struct GuildCardStats {
    let members: Int
    let online: Int
    let reputation: String
}

// MARK: - Card

struct GuildCardView: View {
    let guild: RLGuildDTO

    var style: GuildCardStyle = .switchRow
    /// Your role in this guild, shown at the head of the footer strip.
    var role: RLMemberRole? = nil
    var isCurrent: Bool = false
    var isSelected: Bool = false
    var isJoined: Bool = false
    var preferredLanguage: String = ""
    var preferredLocation: String = ""
    /// Leaderboard rank, rendered ahead of the crest.
    var rank: Int? = nil
    /// Overrides the footer figures, and gives `.compact` a footer it otherwise omits.
    var stats: GuildCardStats? = nil
    /// Trailing value for `.compact` (leaderboard reputation / accuracy).
    var trailingMetric: String? = nil
    var trailingMetricColor: Color? = nil
    /// `nil` makes the card non-interactive — used by `.pending`.
    var onTap: (() -> Void)? = nil

    private static let cornerRadius: CGFloat = 14
    private static let crestSize: CGFloat = 42

    // MARK: Derived

    private var isEmphasised: Bool { isCurrent || isSelected }

    private var showsFooter: Bool {
        switch style {
        case .switchRow, .discover, .selection: return true
        case .pending: return false
        case .compact: return stats != nil
        }
    }

    private var ownerName: String {
        guild.ownerDisplayName ?? guild.ownerUsername ?? "Unknown owner"
    }

    /// The single caption line under the guild name. Discover has no room for
    /// one — its access pills and description occupy that slot instead.
    private var secondaryLine: String? {
        switch style {
        case .switchRow, .selection, .compact: return "Owned by \(ownerName)"
        case .pending: return "An admin is reviewing your request"
        case .discover: return nil
        }
    }

    private var fillOverride: Color? {
        isEmphasised
            ? AppColors.guildReputationAccent.opacity(CGFloat(AppColors.guildSwitchRowSelectedFillOpacity))
            : nil
    }

    private var borderOverride: Color? {
        isEmphasised
            ? AppColors.guildReputationAccent.opacity(CGFloat(AppColors.guildSwitchRowSelectedStrokeOpacity))
            : nil
    }

    private var localeMatches: Bool {
        LocaleOptionCatalog.matchScore(
            language: guild.language,
            location: guild.location,
            preferredLanguage: preferredLanguage,
            preferredLocation: preferredLocation
        ) > 0
    }

    // MARK: Body

    var body: some View {
        Group {
            if let onTap {
                UnifiedContentCard(
                    onTap: onTap,
                    semanticBorderColor: borderOverride,
                    cornerRadius: Self.cornerRadius,
                    fillOverride: fillOverride
                ) {
                    cardBody
                }
            } else {
                cardBody
                    .background(
                        RoundedRectangle(cornerRadius: Self.cornerRadius)
                            .fill(fillOverride ?? AppColors.contentCardFill(isUnread: false, isPressed: false))
                            .overlay(
                                RoundedRectangle(cornerRadius: Self.cornerRadius)
                                    .strokeBorder(
                                        borderOverride ?? AppColors.markerListCapsuleStroke,
                                        lineWidth: 1
                                    )
                            )
                    )
            }
        }
        // The elevation cue guild cards never had. Painted as a shape *behind* the
        // card rather than a modifier on it, so the shadow is cast by the card
        // silhouette and not by every glyph inside it.
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(AppColors.guildCardBase)
                .shadow(color: AppColors.guildCardShadow, radius: 10, x: 0, y: 3)
        )
    }

    private var cardBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if let rank {
                    Text("\(rank)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                        .frame(minWidth: 20, alignment: .leading)
                        .padding(.top, 10)
                }

                GuildCrestView(guild: guild, size: Self.crestSize)

                VStack(alignment: .leading, spacing: 4) {
                    nameRow

                    if let secondaryLine {
                        Text(secondaryLine)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                            .lineLimit(1)
                    }

                    if style == .discover {
                        accessPills

                        if let description = guild.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, showsFooter ? 10 : 12)

            if showsFooter {
                GuildMetaFooter(
                    roleName: role?.displayName,
                    roleColor: role?.color,
                    memberCount: stats?.members ?? guild.memberCount,
                    membersOnline: stats?.online ?? guild.membersOnline,
                    reputationDisplay: stats?.reputation ?? guild.reputationDisplay,
                    language: guild.language,
                    location: guild.location,
                    isLocaleMatch: localeMatches,
                    cornerRadius: Self.cornerRadius
                )
            }
        }
    }

    // MARK: Name row

    private var nameRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(guild.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if guild.isSystemGuild && style != .discover {
                GuildCardPill(text: "System", tint: AppColors.guildReputationAccent)
            }

            Spacer(minLength: 4)

            accessory
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch style {
        case .switchRow:
            if isCurrent {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                    Text("Current")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(AppColors.guildReputationAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppColors.guildReputationAccent.opacity(0.18)))
            } else {
                chevron
            }

        case .discover:
            chevron

        case .pending:
            GuildCardPill(text: "Pending", tint: AppColors.statusWarning)

        case .selection:
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(
                    isSelected
                        ? AppColors.guildReputationAccent
                        : AppColors.whiteText.opacity(0.28)
                )

        case .compact:
            if let trailingMetric {
                Text(trailingMetric)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(trailingMetricColor ?? AppColors.guildReputationAccent)
            } else {
                chevron
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppColors.whiteText.opacity(0.35))
    }

    // MARK: Access pills (discover only)

    private var accessPills: some View {
        HStack(spacing: 6) {
            if guild.isSystemGuild {
                GuildCardPill(text: "System", tint: AppColors.guildReputationAccent)
            } else if guild.isOpen {
                GuildCardPill(text: "Open", tint: AppColors.guildReputationAccent)
            } else {
                GuildCardPill(text: "Private", tint: AppColors.whiteText.opacity(0.55))
            }

            if isJoined {
                GuildCardPill(text: "Joined", tint: AppColors.bullCandleGreen)
            }
        }
        .padding(.top, 1)
    }
}

// MARK: - Staggered appearance

/// Fades and lifts a list row in, offset by its position.
///
/// Guild lists used to snap in as a block while guild detail and create-guild
/// staggered their sections, so the two halves of the same flow felt unrelated.
///
/// State lives per row, and `ForEach` keys rows by guild id, so a background
/// refresh that returns the same guilds leaves already-revealed rows alone
/// instead of replaying the animation over them.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    /// Capped so a long guild list doesn't spend a second and a half revealing.
    private var delay: Double { Double(min(index, 6)) * 0.05 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85).delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// See `StaggeredAppear`. Apply to rows inside a `ForEach`, passing the offset.
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Section card

/// Panel container for guild-flow screens (detail, create), matching
/// `GuildCardView`'s surface so a screen of cards reads as one family.
///
/// Replaces two byte-identical `private func sectionCard` helpers that sat in
/// the same file and could not see each other, plus one section that had been
/// hand-inlined with a different stroke colour than its three siblings.
struct GuildSectionCard<Content: View>: View {
    var title: String? = nil
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    private static var cornerRadius: CGFloat { 14 }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(AppColors.contentCardFill(isUnread: false, isPressed: false))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cornerRadius)
                        .strokeBorder(AppColors.markerListCapsuleStroke, lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(AppColors.guildCardBase)
                .shadow(color: AppColors.guildCardShadow, radius: 10, x: 0, y: 3)
        )
    }
}

// MARK: - Pill

/// Small capsule used inside guild cards. Tint drives both text and fill, so a
/// pill can never end up with a colour pairing that no other pill uses — which
/// is how "Open" and "Joined" ended up swapped between two header variants.
struct GuildCardPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.16)))
            .fixedSize()
    }
}
