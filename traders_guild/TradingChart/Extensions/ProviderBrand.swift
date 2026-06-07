//
//  ProviderBrand.swift
//  traders_guild
//
//  Client-side brand identity for market-data providers / exchanges.
//
//  Maps a provider or exchange label (e.g. "BINANCE", "Coinbase", "NASDAQ") to a
//  recognizable brand color + a short monogram so provider references render with
//  identity instead of a generic pill. Purely cosmetic and client-only — it derives
//  entirely from values the backend already sends (providerDisplayLabel /
//  activeMarketProvider / exchange). No logo assets, no trademark/licensing exposure.
//
//  Unknown providers degrade gracefully to a neutral chip (today's look).
//

import SwiftUI

struct ProviderBrand {
    let color: Color
    /// Single-letter monogram shown in a brand-colored tile. Empty == use a dot instead.
    let monogram: String
    /// Contrasting text color for the monogram tile (computed from brand luminance).
    let onColor: Color

    /// Neutral fallback for unknown providers — keeps the previous blue chip styling.
    static let neutral = ProviderBrand(color: AppColors.statusInfo, monogram: "", onColor: .white)

    /// Resolve a brand from any provider / exchange label, case- and format-insensitive.
    /// Matches on the first known token contained in the label so "BINANCE",
    /// "Binance Spot" and "binance_us" all resolve to the same brand.
    static func resolve(_ rawLabel: String?) -> ProviderBrand {
        guard let raw = rawLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return .neutral
        }
        let lower = raw.lowercased()
        for entry in orderedTable where lower.contains(entry.key) {
            return entry.brand
        }
        return .neutral
    }

    // MARK: - Brand table

    private struct Entry { let key: String; let brand: ProviderBrand }

    /// Ordered so the most specific / common providers match first. Keys are
    /// lowercase substrings tested against the provider/exchange label.
    private static let orderedTable: [Entry] = [
        Entry(key: "binance",  brand: brand("#F0B90B", "B")),
        Entry(key: "coinbase", brand: brand("#0052FF", "C")),
        Entry(key: "kraken",   brand: brand("#7132F5", "K")),
        Entry(key: "bybit",    brand: brand("#F7A600", "B")),
        Entry(key: "bitstamp", brand: brand("#149147", "B")),
        Entry(key: "okx",      brand: brand("#1A1A1A", "O")),
        Entry(key: "oanda",    brand: brand("#C8102E", "O")),
        Entry(key: "nasdaq",   brand: brand("#0096D6", "N")),
        Entry(key: "nyse",     brand: brand("#003DA5", "N")),
        Entry(key: "lse",      brand: brand("#00A8E1", "L")),
        Entry(key: "polygon",  brand: brand("#5B4FE9", "P")),
    ]

    private static func brand(_ hex: String, _ monogram: String) -> ProviderBrand {
        ProviderBrand(
            color: Color(hex: hex) ?? AppColors.statusInfo,
            monogram: monogram,
            onColor: contrastColor(forHex: hex)
        )
    }

    /// Pick black or white text for a brand tile based on the brand's relative luminance.
    private static func contrastColor(forHex hex: String) -> Color {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let rgb = UInt32(cleaned, radix: 16) else { return .white }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? Color.black.opacity(0.85) : .white
    }
}
