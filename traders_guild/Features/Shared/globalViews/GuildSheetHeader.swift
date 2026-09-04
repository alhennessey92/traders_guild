//
//  GuildSheetHeader.swift
//  traders_guild
//
//  The standard header for a guild-scoped sheet.
//

import SwiftUI

/// Shared geometry, so callers can size a trailing badge to match the crest.
enum GuildSheetHeaderMetrics {
    static let bannerHeight: CGFloat = 88
    static let crestSize: CGFloat = 56
    static let crestOverlap: CGFloat = 26
}

/// The guild's own banner and crest, then the sheet's title.
///
/// Extracted from the Discord setup sheet's hero, which is the version signed
/// off on Android. Every other guild-scoped sheet led with a grabber and a line
/// of text, so nothing on screen said *which* guild you were about to share to
/// — the one thing the reader most needs when they belong to several.
///
/// `trailingBadge` joins a second circle onto the crest with a short accent bar,
/// for sheets that are about the guild *plus* something else (Discord). Nil
/// gives the crest alone.
///
/// `titleBadge` sits beside the title — used by the marker share sheet to name
/// the marker's type.
///
/// Geometry is Android's: the banner keeps its 14pt corner and sits inside the
/// sheet's own horizontal inset, rather than running edge to edge. That is the
/// version the user signed off on; the iOS hero was ported later and never
/// seen. The ring fill reads as a divergence between the two files but is not
/// one — iOS `gradientBackgroundDark` and Android `gradientBackground` are the
/// same token (#010105 / #181C28 / #C0C2C9).
struct GuildSheetHeader<TrailingBadge: View, TitleBadge: View>: View {
    let guild: RLGuildDTO?
    let title: String
    var subtitle: String?
    var accent: Color?
    @ViewBuilder var trailingBadge: () -> TrailingBadge
    @ViewBuilder var titleBadge: () -> TitleBadge

    private var tint: Color { accent ?? GuildTheme.accent(for: guild) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            hero
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppColors.whiteText)
                        .fixedSize(horizontal: false, vertical: true)
                    titleBadge()
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let guild {
                    GuildBannerView(guild: guild, height: GuildSheetHeaderMetrics.bannerHeight)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint.opacity(0.18))
                        .frame(height: GuildSheetHeaderMetrics.bannerHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: GuildSheetHeaderMetrics.bannerHeight, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 0) {
                Self.ringedBadge {
                    Group {
                        if let guild {
                            GuildCrestView(guild: guild, size: GuildSheetHeaderMetrics.crestSize - 4)
                        } else {
                            Circle().fill(tint.opacity(0.16))
                                .frame(width: GuildSheetHeaderMetrics.crestSize - 4, height: GuildSheetHeaderMetrics.crestSize - 4)
                        }
                    }
                }
                if TrailingBadge.self != EmptyView.self {
                    Rectangle()
                        .fill(tint.opacity(0.55))
                        .frame(width: 18, height: 2)
                    Self.ringedBadge { trailingBadge() }
                }
            }
            .padding(.leading, 14)
        }
        // The banner plus the part of the crest row that hangs below it. Sized
        // here rather than offset from a stack, so the sheet does not reserve —
        // and then leave — the height the row was lifted out of.
        .frame(height: GuildSheetHeaderMetrics.bannerHeight + GuildSheetHeaderMetrics.crestSize - GuildSheetHeaderMetrics.crestOverlap)
    }

    /// A badge punched out of the banner, so the artwork behind it does not touch it.
    @ViewBuilder
    static func ringedBadge<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle().fill(AppColors.gradientBackgroundDark)
            content()
        }
        .frame(width: GuildSheetHeaderMetrics.crestSize, height: GuildSheetHeaderMetrics.crestSize)
    }
}

extension GuildSheetHeader where TrailingBadge == EmptyView, TitleBadge == EmptyView {
    init(guild: RLGuildDTO?, title: String, subtitle: String? = nil, accent: Color? = nil) {
        self.init(
            guild: guild,
            title: title,
            subtitle: subtitle,
            accent: accent,
            trailingBadge: { EmptyView() },
            titleBadge: { EmptyView() }
        )
    }
}

extension GuildSheetHeader where TitleBadge == EmptyView {
    init(
        guild: RLGuildDTO?,
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        @ViewBuilder trailingBadge: @escaping () -> TrailingBadge
    ) {
        self.init(
            guild: guild,
            title: title,
            subtitle: subtitle,
            accent: accent,
            trailingBadge: trailingBadge,
            titleBadge: { EmptyView() }
        )
    }
}

extension GuildSheetHeader where TrailingBadge == EmptyView {
    init(
        guild: RLGuildDTO?,
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        @ViewBuilder titleBadge: @escaping () -> TitleBadge
    ) {
        self.init(
            guild: guild,
            title: title,
            subtitle: subtitle,
            accent: accent,
            trailingBadge: { EmptyView() },
            titleBadge: titleBadge
        )
    }
}
