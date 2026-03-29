import SwiftUI

/// Unified symbol icon renderer with source priority:
/// iconUrl (remote) -> iconName (bundled asset) -> mapped bundled asset -> gradient + fallback initial.
struct TradingSymbolIconView: View {
    let symbol: RLTradingSymbolDTO
    var size: CGFloat = 44
    var cornerRadiusRatio: CGFloat = 0.22
    var strokeOpacity: Double = 0.15
    var showShadow: Bool = false

    private var cornerRadius: CGFloat {
        max(6, size * cornerRadiusRatio)
    }

    private var remoteIconURL: URL? {
        guard let iconUrl = symbol.iconUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !iconUrl.isEmpty else {
            return nil
        }

        if let absoluteURL = URL(string: iconUrl), absoluteURL.scheme != nil {
            return absoluteURL
        }

        let base = APIService.core.baseURL
        let mediaBase: String
        if let apiRange = base.range(of: "/api/v1", options: .backwards) {
            mediaBase = String(base[..<apiRange.lowerBound])
        } else {
            mediaBase = base
        }

        if iconUrl.hasPrefix("/") {
            return URL(string: mediaBase + iconUrl)
        }
        return URL(string: mediaBase + "/" + iconUrl)
    }

    private var iconAssetName: String? {
        if let bundledName = BundledTradingSymbolIconResolver.bundledAssetName(for: symbol.iconName) {
            return bundledName
        }
        return BundledTradingSymbolIconResolver.assetName(for: symbol.ticker, assetClass: symbol.assetClass)
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
                color: showShadow ? symbol.primaryColorValue.opacity(0.35) : .clear,
                radius: showShadow ? 4 : 0,
                x: 0,
                y: 2
            )
    }

    @ViewBuilder
    private var iconContent: some View {
        if let remoteURL = remoteIconURL {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackContent
                case .empty:
                    fallbackContent.opacity(0.55)
                @unknown default:
                    fallbackContent
                }
            }
        } else if let iconAssetName {
            Image(iconAssetName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackContent
        }
    }

    private var fallbackContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    symbol.primaryColorValue,
                    symbol.secondaryColorValue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(symbol.fallbackInitial)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

}
