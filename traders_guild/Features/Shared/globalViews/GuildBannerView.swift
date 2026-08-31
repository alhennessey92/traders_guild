//
//  GuildBannerView.swift
//  traders_guild
//
//  A guild's wide header artwork, and the only place its fallback is defined.
//
//  Guilds used to be told apart by a 38–48pt circular crest and nothing else, which left
//  every guild page looking the same above the fold. This is the counterpart to
//  `GuildCrestView`: one component, every render site.
//
//  A guild without an uploaded banner is not a hole in the layout. It gets the app's own
//  honeycomb lattice struck in the guild's crest colour, fading from the top-left, with the
//  guild's name set across the middle — so the page reads as *this* guild, and uploading
//  artwork is an upgrade rather than a repair. A flat gradient was the first attempt and it
//  read as an empty band.
//

import SwiftUI

struct GuildBannerView: View {
    let bannerUrl: String?
    let crestColor: String?
    let guildName: String
    var height: CGFloat = 116
    var cornerRadius: CGFloat = 14

    init(guild: RLGuildDTO, height: CGFloat = 116, cornerRadius: CGFloat = 14) {
        self.bannerUrl = guild.bannerUrl
        self.crestColor = guild.crestColor
        self.guildName = guild.name
        self.height = height
        self.cornerRadius = cornerRadius
    }

    /// For create/settings previews, before a guild exists to read from.
    init(
        bannerUrl: String?,
        crestColor: String?,
        guildName: String,
        height: CGFloat = 116,
        cornerRadius: CGFloat = 14
    ) {
        self.bannerUrl = bannerUrl
        self.crestColor = crestColor
        self.guildName = guildName
        self.height = height
        self.cornerRadius = cornerRadius
    }

    private var tint: Color {
        GuildCrestCatalog.color(for: crestColor)
    }

    private var displayName: String {
        guildName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Long names step down rather than wrap or clip, then scale with the banner so the
    /// drawer's shorter header reads the same as the detail page's.
    private var nameScale: CGFloat { height / 116 }

    private var nameFontSize: CGFloat {
        let base: CGFloat = displayName.count <= 14 ? 26 : (displayName.count <= 22 ? 21 : 17)
        return base * nameScale
    }

    private var nameTracking: CGFloat {
        let ratio: CGFloat = displayName.count <= 14 ? 0.14 : (displayName.count <= 22 ? 0.10 : 0.06)
        return nameFontSize * ratio
    }

    var body: some View {
        ZStack {
            generatedBanner

            if let bannerUrl, !bannerUrl.isEmpty, let url = URL(string: bannerUrl) {
                // Reuses the avatar cache: same first-party `/_tg_media` origin, same
                // no-placeholder-flash behaviour.
                CachedAvatarImage(url: url, size: height, initials: "")
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppColors.whiteText.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Generated fallback

    private var generatedBanner: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.42), tint.opacity(0.12), AppColors.sheetBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                // The lattice is stroked with a radial gradient rather than masked, so it
                // simply stops existing where it should rather than being painted and hidden.
                context.stroke(
                    Self.honeycombPath(in: size, hexSize: 17 * nameScale),
                    with: .radialGradient(
                        Gradient(colors: [
                            tint.opacity(0.34),
                            tint.opacity(0.18),
                            tint.opacity(0),
                        ]),
                        center: CGPoint(x: size.width * 0.18, y: -size.height * 0.10),
                        startRadius: 0,
                        endRadius: size.width * 0.86
                    ),
                    lineWidth: 1.4
                )

                // Clean ground under the name, whatever the lattice is doing behind it.
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.031, green: 0.043, blue: 0.063).opacity(0.55),
                            Color(red: 0.031, green: 0.043, blue: 0.063).opacity(0),
                        ]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.56),
                        startRadius: 0,
                        endRadius: size.width * 0.72
                    )
                )
            }

            Text(displayName)
                .font(.system(size: nameFontSize, weight: .heavy))
                .tracking(nameTracking)
                .foregroundColor(AppColors.whiteText.opacity(0.96))
                .shadow(color: tint.opacity(0.40), radius: 20 * nameScale, y: 2)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 18)
        }
    }

    // MARK: - Honeycomb geometry

    /// The app's honeycomb motif: pointy-top hexagons, offset row by row.
    private static func honeycombPath(in size: CGSize, hexSize s: CGFloat) -> Path {
        var path = Path()
        guard s > 0 else { return path }
        let width = sqrt(3) * s
        let rowStep = s * 1.5

        var row = 0
        var y = -s
        while y < size.height + s {
            let offset = row.isMultiple(of: 2) ? 0 : width / 2
            var x = -width + offset
            while x < size.width + width {
                path.addPath(hexagon(center: CGPoint(x: x + width / 2, y: y + s), size: s))
                x += width
            }
            y += rowStep
            row += 1
        }
        return path
    }

    private static func hexagon(center: CGPoint, size s: CGFloat) -> Path {
        var path = Path()
        for corner in 0..<6 {
            let angle = CGFloat.pi / 180 * (60 * CGFloat(corner) - 90)
            let point = CGPoint(
                x: center.x + s * cos(angle),
                y: center.y + s * sin(angle)
            )
            if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Guild banners") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(
                Array(zip(GuildCrestCatalog.colorKeys, [
                    "Apex Traders", "Macro Metals", "Vanguard",
                    "London Session Scalpers", "Quiet Alpha", "Delta One", "Signal",
                ])),
                id: \.0
            ) { key, name in
                GuildBannerView(bannerUrl: nil, crestColor: key, guildName: name)
                GuildBannerView(bannerUrl: nil, crestColor: key, guildName: name, height: 76)
            }
        }
        .padding()
    }
    .background(AppColors.sheetBackground)
}
#endif
