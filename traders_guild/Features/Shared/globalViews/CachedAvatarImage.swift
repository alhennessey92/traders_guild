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
    private let responseCache: URLCache
    private let session: URLSession

    /// One network load per URL at a time. A prefetch and the avatar view that
    /// needs the same picture used to fetch it twice; now the second caller
    /// awaits the first.
    ///
    /// Each load carries a token. Publishing a finished load into the cache and
    /// invalidating a URL both happen under `lock`, and publication only happens
    /// while the load's token is still the registered one — so a load that
    /// finishes after its URL was removed (an avatar changed or deleted
    /// mid-flight) can never put the old picture back, and no second request
    /// can start between a load finishing and its picture landing.
    private struct PendingLoad {
        let token: UUID
        let task: Task<UIImage, Error>
    }
    private var pendingLoads: [URL: PendingLoad] = [:]
    /// Guards `pendingLoads` and every cache write. Not recursive: the
    /// `…Locked` helpers assume it is held and never take it.
    private let lock = NSLock()

    /// Test seam: runs after a load's response arrives and before it is
    /// published, which is exactly the window an invalidation can race.
    var beforePublishingLoad: ((URL) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _beforePublishingLoad }
        set { lock.lock(); _beforePublishingLoad = newValue; lock.unlock() }
    }
    private var _beforePublishingLoad: ((URL) -> Void)?

    private convenience init() {
        self.init(configuration: .default, responseCache: .shared)
    }

    /// Injectable for tests; the app uses `shared`.
    ///
    /// The transport never caches on its own: `configuration` is copied with
    /// its URL cache removed. Otherwise URLSession would store a response the
    /// moment it arrived — including one for an avatar removed while the
    /// request was in flight — beside the token check in `finishLoad`, and
    /// `image(for:)` would read the stale picture back out. Responses reach
    /// `responseCache` only through that check.
    init(configuration: URLSessionConfiguration, responseCache: URLCache) {
        let transport = configuration.copy() as! URLSessionConfiguration
        transport.urlCache = nil
        transport.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: transport)
        self.responseCache = responseCache
        // Shared in-memory image cache reused by both avatars and symbol icons.
        cache.countLimit = 400
    }

    func image(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cachedImageLocked(for: url)
    }

    func store(_ image: UIImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, data: Data, response: URLResponse, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        storeLocked(image, data: data, response: response, for: url)
    }

    func loadImage(for url: URL) async throws -> UIImage {
        switch cachedOrPendingLoad(for: url) {
        case .cached(let image):
            return image
        case .pending(let task):
            return try await task.value
        }
    }

    private enum LoadSource {
        case cached(UIImage)
        case pending(Task<UIImage, Error>)
    }

    /// The cached picture, else the in-flight load, else a new load — decided
    /// in one critical section, so a load that finished a moment ago is found
    /// in the cache rather than requested again.
    ///
    /// The load is unstructured on purpose: several callers share it, so one
    /// caller's cancellation (an avatar scrolled away) must not fail the others.
    /// Callers that publish to UI check their own cancellation instead.
    private func cachedOrPendingLoad(for url: URL) -> LoadSource {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedImageLocked(for: url) {
            return .cached(cached)
        }
        if let pending = pendingLoads[url] {
            return .pending(pending.task)
        }
        let token = UUID()
        let task = Task<UIImage, Error> { [session] in
            // The response cache was already consulted under the lock above;
            // the transport has none of its own.
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }
                self.beforePublishingLoad?(url)
                self.finishLoad(url: url, token: token, published: (image, data, response))
                return image
            } catch {
                self.finishLoad(url: url, token: token, published: nil)
                throw error
            }
        }
        pendingLoads[url] = PendingLoad(token: token, task: task)
        return .pending(task)
    }

    /// Retire a load and, if it is still the registered one, publish its
    /// picture — atomically. If the URL was removed in flight the caller still
    /// gets the picture it asked for, but the cache does not resurrect it.
    private func finishLoad(
        url: URL,
        token: UUID,
        published: (image: UIImage, data: Data, response: URLResponse)?
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard pendingLoads[url]?.token == token else { return }
        pendingLoads[url] = nil
        if let published {
            storeLocked(published.image, data: published.data, response: published.response, for: url)
        }
    }

    /// How many loads are in flight. For tests.
    var pendingLoadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingLoads.count
    }

    func prefetch(urlStrings: [String]) {
        let urls = Set(urlStrings.compactMap { URL(string: $0) })
        for url in urls where image(for: url) == nil {
            Task.detached(priority: .utility) { [self] in
                _ = try? await self.loadImage(for: url)
            }
        }
    }

    /// Forget a picture: memory, response cache and any in-flight load, in one
    /// step. The in-flight load still completes for whoever awaits it, but will
    /// not publish, and the next request starts afresh.
    func removeImage(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        removeLocked(url: url, key: url.absoluteString)
    }

    func removeImage(forURLString urlString: String?) {
        guard let urlString, !urlString.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        if let url = URL(string: urlString) {
            removeLocked(url: url, key: urlString)
        } else {
            cache.removeObject(forKey: urlString as NSString)
        }
    }

    // MARK: Lock held

    private func cachedImageLocked(for url: URL) -> UIImage? {
        if let memoryCached = cache.object(forKey: url.absoluteString as NSString) {
            return memoryCached
        }

        let request = URLRequest(url: url)
        guard let cachedResponse = responseCache.cachedResponse(for: request),
              let cachedImage = UIImage(data: cachedResponse.data) else {
            return nil
        }

        cache.setObject(cachedImage, forKey: url.absoluteString as NSString)
        return cachedImage
    }

    private func storeLocked(_ image: UIImage, data: Data, response: URLResponse, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
        responseCache.storeCachedResponse(
            CachedURLResponse(response: response, data: data),
            for: URLRequest(url: url)
        )
    }

    private func removeLocked(url: URL, key: String) {
        pendingLoads[url] = nil
        cache.removeObject(forKey: key as NSString)
        cache.removeObject(forKey: url.absoluteString as NSString)
        responseCache.removeCachedResponse(for: URLRequest(url: url))
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
                guard !Task.isCancelled else { return }
                image = cached
                loadFailed = false
            }
            return
        }

        await MainActor.run {
            guard !Task.isCancelled else { return }
            image = nil
            loadFailed = false
        }

        let outcome = await Self.load(url)
        await MainActor.run {
            // Re-checked on the main actor, where the state is written: `.task(id:)`
            // cancels this task when the URL changes, and the shared load it
            // awaited does not cancel with it.
            guard !Task.isCancelled else { return }
            switch outcome {
            case .loaded(let uiImage):
                image = uiImage
                loadFailed = false
            case .failed:
                loadFailed = true
            case .cancelled:
                break
            }
        }
    }

    enum LoadOutcome: Equatable {
        case loaded(UIImage)
        case failed
        /// The caller stopped wanting the picture — the view's URL changed or
        /// it left the screen — so nothing may be painted from this load.
        case cancelled
    }

    /// Load `url` for display, through the shared loader so a prefetch already
    /// fetching this picture is awaited rather than repeated.
    ///
    /// That load is shared and does not cancel with the caller, so the caller's
    /// own cancellation is checked before any result is handed back.
    static func load(_ url: URL, using cache: AvatarImageCache = .shared) async -> LoadOutcome {
        do {
            let uiImage = try await cache.loadImage(for: url)
            return Task.isCancelled ? .cancelled : .loaded(uiImage)
        } catch {
            return Task.isCancelled ? .cancelled : .failed
        }
    }
}
