import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BundledTradingSymbolIconResolver {
    static func assetName(for ticker: String?, assetClass: String?) -> String? {
        let normalizedTicker = normalizedTicker(ticker)
        let normalizedAssetClass = assetClass?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedAssetClass == "crypto" || normalizedAssetClass == nil {
            if normalizedTicker.hasPrefix("BTC") { return "icon_btc" }
            if normalizedTicker.hasPrefix("ETH") { return "icon_eth" }
            if normalizedTicker.hasPrefix("SOL") { return "icon_sol" }
            if normalizedTicker.hasPrefix("ADA") { return "icon_ada" }
            if normalizedTicker.hasPrefix("XRP") { return "icon_xrp" }
            if normalizedTicker.hasPrefix("DOGE") { return "icon_doge" }
            if normalizedTicker.hasPrefix("SHIB") { return "icon_shib" }
            if normalizedTicker.hasPrefix("ATOM") { return "icon_atom" }
            if normalizedTicker.hasPrefix("LTC") { return "icon_ltc" }
        }

        switch normalizedTicker {
        case "EURUSD":
            return "icon_eurusd"
        case "GBPUSD":
            return "icon_gbpusd"
        case "AUDUSD":
            return "icon_audusd"
        case "USDCHF":
            return "icon_usdchf"
        case "USDJPY":
            return "icon_usdjpy"
        default:
            return nil
        }
    }

    static func bundledAssetName(for iconName: String?) -> String? {
        guard let iconName = sanitized(iconName), assetExists(named: iconName) else { return nil }
        return iconName
    }

    static func systemIconName(for iconName: String?) -> String? {
        guard let iconName = sanitized(iconName), !assetExists(named: iconName) else { return nil }
        return iconName
    }

    static func normalizedTicker(_ ticker: String?) -> String {
        sanitized(ticker)?
            .uppercased()
            .filter {
                String($0).rangeOfCharacter(from: .alphanumerics) != nil
            } ?? ""
    }

    static func assetExists(named assetName: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: assetName) != nil
        #else
        return false
        #endif
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

struct TickerSymbolIconView: View {
    let ticker: String
    var assetClass: String? = nil
    var brandColorHex: String? = nil
    var size: CGFloat = 22
    var cornerRadiusRatio: CGFloat = 0.24
    var strokeOpacity: Double = 0.15
    var showShadow: Bool = false

    private var cornerRadius: CGFloat {
        max(6, size * cornerRadiusRatio)
    }

    private var assetName: String? {
        BundledTradingSymbolIconResolver.assetName(for: ticker, assetClass: assetClass)
    }

    private var fallbackPrimaryColor: Color {
        if let brandColorHex, let color = Color(hex: brandColorHex) {
            return color
        }

        switch assetClass?.lowercased() {
        case "crypto":
            return AppColors.statusWarning70
        case "forex":
            return AppColors.statusInfo70
        case "stocks", "indices":
            return AppColors.statusPositive70
        case "commodities", "futures":
            return AppColors.statusHighlight80
        default:
            return AppColors.surfaceGray50
        }
    }

    private var fallbackSecondaryColor: Color {
        fallbackPrimaryColor.opacity(0.45)
    }

    private var fallbackInitial: String {
        let normalized = BundledTradingSymbolIconResolver.normalizedTicker(ticker)
        return String(normalized.prefix(1)).uppercased()
    }

    var body: some View {
        iconContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.systemWhite.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(
                color: showShadow ? fallbackPrimaryColor.opacity(0.35) : .clear,
                radius: showShadow ? 4 : 0,
                x: 0,
                y: 2
            )
    }

    @ViewBuilder
    private var iconContent: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackContent
        }
    }

    private var fallbackContent: some View {
        ZStack {
            LinearGradient(
                colors: [fallbackPrimaryColor, fallbackSecondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(fallbackInitial)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.onAccentForeground)
        }
    }
}
