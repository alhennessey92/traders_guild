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

    @State private var loadedImage: UIImage?
    @State private var loadFailed: Bool = false

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
            remoteIconView(for: remoteURL)
        } else if let iconAssetName {
            Image(iconAssetName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackContent
        }
    }

    @ViewBuilder
    private func remoteIconView(for url: URL) -> some View {
        // Synchronous cache hit: render immediately, no decode-flash on scroll.
        let cached = AvatarImageCache.shared.image(for: url) ?? loadedImage
        if let cached {
            Image(uiImage: cached)
                .resizable()
                .scaledToFill()
        } else if loadFailed {
            fallbackContent
        } else {
            fallbackContent
                .opacity(0.55)
                .task(id: url.absoluteString) {
                    await loadRemoteIcon(url: url)
                }
        }
    }

    private func loadRemoteIcon(url: URL) async {
        if let cached = AvatarImageCache.shared.image(for: url) {
            await MainActor.run {
                if loadedImage == nil { loadedImage = cached }
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run { loadFailed = true }
                return
            }
            AvatarImageCache.shared.store(uiImage, for: url)
            await MainActor.run { loadedImage = uiImage }
        } catch {
            await MainActor.run { loadFailed = true }
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
                .foregroundColor(AppColors.onAccentForeground)
        }
    }

}
