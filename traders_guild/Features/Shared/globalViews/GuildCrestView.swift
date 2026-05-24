//
//  GuildCrestView.swift
//  traders_guild
//
//  A guild's emblem. Either an uploaded image (rendered circular, like a user
//  avatar) or a chosen SF Symbol shield tinted with a chosen colour, shown in a
//  matching circle. This is the single shared component for every guild-emblem render
//  site — switch row, discover row, detail header, create preview, registration
//  guild selection, drawer headers, profile guild card.
//
//  Reputation shields in member/user-list rows are NOT guild emblems and do
//  not use this component.
//

import SwiftUI

// MARK: - Crest catalog

/// Curated guild crest symbols and colours. Keys are platform-neutral (shared
/// with the backend and the Android client); this catalog maps them to the
/// iOS SF Symbol names and colours.
enum GuildCrestCatalog {
    static let symbolKeys = [
        "checkered", "plain", "left_half", "right_half",
        "bolt", "star_of_life", "checkmark", "exclamation",
    ]
    static let colorKeys = ["brand", "gold", "green", "blue", "red", "violet", "steel"]

    static let defaultSymbolKey = "checkered"
    static let defaultColorKey = "brand"

    /// Neutral crest-symbol key → SF Symbol name. Unknown keys fall back to the
    /// default checkered shield.
    static func sfSymbol(for key: String?) -> String {
        switch key ?? defaultSymbolKey {
        case "plain":        return "shield.fill"
        case "left_half":    return "shield.lefthalf.filled"
        case "right_half":   return "shield.righthalf.filled"
        case "bolt":         return "bolt.shield.fill"
        case "star_of_life": return "staroflife.shield.fill"
        case "checkmark":    return "checkmark.shield.fill"
        case "exclamation":  return "exclamationmark.shield.fill"
        default:             return "shield.pattern.checkered"
        }
    }

    /// Neutral crest-colour key → Color. `brand` resolves fresh each call so it
    /// tracks the active theme. Unknown keys fall back to the brand colour.
    static func color(for key: String?) -> Color {
        switch key ?? defaultColorKey {
        case "gold":   return Color(red: 0.80, green: 0.66, blue: 0.36)
        case "green":  return Color(red: 0.38, green: 0.66, blue: 0.46)
        case "blue":   return Color(red: 0.40, green: 0.58, blue: 0.82)
        case "red":    return Color(red: 0.80, green: 0.44, blue: 0.40)
        case "violet": return Color(red: 0.62, green: 0.50, blue: 0.78)
        case "steel":  return Color(red: 0.62, green: 0.66, blue: 0.71)
        default:       return AppColors.guildReputationAccent
        }
    }
}

// MARK: - Guild crest view

struct GuildCrestView: View {
    let imageUrl: String?
    let crestSymbol: String?
    let crestColor: String?
    let fallbackInitial: Character
    var size: CGFloat = 44

    /// Render a guild's emblem.
    init(guild: RLGuildDTO, size: CGFloat = 44) {
        self.imageUrl = guild.imageUrl
        self.crestSymbol = guild.crestSymbol
        self.crestColor = guild.crestColor
        self.fallbackInitial = guild.name.first ?? "G"
        self.size = size
    }

    /// Render an emblem from raw fields — used by the create/settings preview
    /// before a guild exists.
    init(
        imageUrl: String? = nil,
        crestSymbol: String?,
        crestColor: String?,
        fallbackInitial: Character = "G",
        size: CGFloat = 44
    ) {
        self.imageUrl = imageUrl
        self.crestSymbol = crestSymbol
        self.crestColor = crestColor
        self.fallbackInitial = fallbackInitial
        self.size = size
    }

    var body: some View {
        if let imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
            // Uploaded guild image — circular, like a user avatar.
            CachedAvatarImage(url: url, size: size, initials: String(fallbackInitial))
        } else {
            // Symbol crest — a tinted shield glyph in a matching circle, so it
            // sits consistently alongside circular uploaded-image emblems.
            let tint = GuildCrestCatalog.color(for: crestColor)
            ZStack {
                Circle().fill(tint.opacity(0.20))
                Image(systemName: GuildCrestCatalog.sfSymbol(for: crestSymbol))
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundColor(tint)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Guild crests") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Symbols").font(.caption).foregroundColor(.gray)
            HStack(spacing: 12) {
                ForEach(GuildCrestCatalog.symbolKeys, id: \.self) { key in
                    GuildCrestView(crestSymbol: key, crestColor: "brand", size: 34)
                }
            }

            Text("Colours").font(.caption).foregroundColor(.gray)
            HStack(spacing: 12) {
                ForEach(GuildCrestCatalog.colorKeys, id: \.self) { key in
                    GuildCrestView(crestSymbol: "checkered", crestColor: key, size: 34)
                }
            }

            Text("Sizes (default)").font(.caption).foregroundColor(.gray)
            HStack(alignment: .center, spacing: 12) {
                ForEach([18, 22, 28, 44, 64], id: \.self) { dim in
                    GuildCrestView(crestSymbol: nil, crestColor: nil, size: CGFloat(dim))
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}
#endif
