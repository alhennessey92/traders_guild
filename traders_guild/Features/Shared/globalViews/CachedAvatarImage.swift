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
                    .onAppear { loadFromCacheOrFetch() }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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

    private func loadFromCacheOrFetch() {
        // Synchronous cache hit — no flash
        if let cached = AvatarImageCache.shared.image(for: url) {
            image = cached
            return
        }

        // Async fetch
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    AvatarImageCache.shared.store(uiImage, for: url)
                    await MainActor.run { image = uiImage }
                } else {
                    await MainActor.run { loadFailed = true }
                }
            } catch {
                await MainActor.run { loadFailed = true }
            }
        }
    }
}
