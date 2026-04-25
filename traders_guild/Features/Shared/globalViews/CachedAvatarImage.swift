//
//  CachedAvatarImage.swift
//  traders_guild
//
//  In-memory avatar image cache to prevent placeholder flash
//  when navigating between screens.
//

import SwiftUI

// MARK: - Avatar Image Cache

final class AvatarImageCache {
    static let shared = AvatarImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }

    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }

    func removeImage(forURLString urlString: String?) {
        guard let urlString, !urlString.isEmpty else { return }
        cache.removeObject(forKey: urlString as NSString)
    }
}

// MARK: - Cached Avatar Image View

struct CachedAvatarImage: View {
    let url: URL
    let size: CGFloat
    let initials: String

    @State private var image: UIImage?
    @State private var loadFailed: Bool = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                initialsPlaceholder
            } else {
                // Check cache synchronously to avoid flash
                initialsPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url.absoluteString) {
            await loadFromCacheOrFetch()
        }
    }

    private var initialsPlaceholder: some View {
        Circle()
            .fill(AppColors.guildReputationAccent.opacity(0.3))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(AppColors.guildReputationAccent)
            )
    }

    private func loadFromCacheOrFetch() async {
        await MainActor.run {
            image = nil
            loadFailed = false
        }

        // Synchronous cache hit — no flash
        if let cached = AvatarImageCache.shared.image(for: url) {
            await MainActor.run { image = cached }
            return
        }

        let targetURL = url

        do {
            let (data, response) = try await URLSession.shared.data(from: targetURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    if targetURL == url {
                        loadFailed = true
                    }
                }
                return
            }

            AvatarImageCache.shared.store(uiImage, for: targetURL)
            await MainActor.run {
                if targetURL == url {
                    image = uiImage
                }
            }
        } catch {
            await MainActor.run {
                if targetURL == url {
                    loadFailed = true
                }
            }
        }
    }
}
