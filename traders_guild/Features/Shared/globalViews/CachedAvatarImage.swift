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
    private let responseCache = URLCache.shared

    private init() {
        // Shared in-memory image cache reused by both avatars and symbol icons.
        cache.countLimit = 400
    }

    func image(for url: URL) -> UIImage? {
        if let memoryCached = cache.object(forKey: url.absoluteString as NSString) {
            return memoryCached
        }

        let request = URLRequest(url: url)
        guard let cachedResponse = responseCache.cachedResponse(for: request),
              let cachedImage = UIImage(data: cachedResponse.data) else {
            return nil
        }

        store(cachedImage, for: url)
        return cachedImage
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, data: Data, response: URLResponse, for url: URL) {
        store(image, for: url)
        let request = URLRequest(url: url)
        responseCache.storeCachedResponse(
            CachedURLResponse(response: response, data: data),
            for: request
        )
    }

    func loadImage(for url: URL) async throws -> UIImage {
        if let cached = image(for: url) {
            return cached
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }

        store(image, data: data, response: response, for: url)
        return image
    }

    func prefetch(urlStrings: [String]) {
        let urls = Set(urlStrings.compactMap { URL(string: $0) })
        for url in urls where image(for: url) == nil {
            Task.detached(priority: .utility) {
                _ = try? await AvatarImageCache.shared.loadImage(for: url)
            }
        }
    }

    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
        responseCache.removeCachedResponse(for: URLRequest(url: url))
    }

    func removeImage(forURLString urlString: String?) {
        guard let urlString, !urlString.isEmpty else { return }
        cache.removeObject(forKey: urlString as NSString)
        if let url = URL(string: urlString) {
            responseCache.removeCachedResponse(for: URLRequest(url: url))
        }
    }
}

// MARK: - Cached Avatar Image View

struct CachedAvatarImage: View {
    let url: URL
    let size: CGFloat
    let initials: String

    @State private var image: UIImage?
    @State private var loadFailed: Bool = false

    init(url: URL, size: CGFloat, initials: String) {
        self.url = url
        self.size = size
        self.initials = initials
        _image = State(initialValue: AvatarImageCache.shared.image(for: url))
    }

    var body: some View {
        Group {
            if let image, !loadFailed {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
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
        // Synchronous cache hit — no flash
        if let cached = AvatarImageCache.shared.image(for: url) {
            await MainActor.run {
                image = cached
                loadFailed = false
            }
            return
        }

        await MainActor.run {
            image = nil
            loadFailed = false
        }

        let targetURL = url

        do {
            let (data, response) = try await URLSession.shared.data(
                for: URLRequest(
                    url: targetURL,
                    cachePolicy: .returnCacheDataElseLoad,
                    timeoutInterval: 30
                )
            )
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

            AvatarImageCache.shared.store(uiImage, data: data, response: httpResponse, for: targetURL)
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
