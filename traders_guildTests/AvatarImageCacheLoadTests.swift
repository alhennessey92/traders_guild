import Foundation
import Testing
import UIKit
@testable import traders_guild

/// Serves avatar requests from memory, optionally holding each one until the
/// test lets it go, and counts what reached the "network".
final class StubAvatarURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _requestCount = 0
    private static var _status = 200
    private static var _held = false
    private static var _cacheable = false
    private static var _waiting: [() -> Void] = []

    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return _requestCount }

    /// `cacheable` answers with HTTP caching headers and lets the loading
    /// system store the response, as a real avatar CDN would.
    static func reset(status: Int = 200, held: Bool = false, cacheable: Bool = false) {
        lock.lock()
        _requestCount = 0
        _status = status
        _held = held
        _cacheable = cacheable
        _waiting = []
        lock.unlock()
    }

    /// Let every held request, and any later one, complete.
    static func release() {
        lock.lock()
        _held = false
        let waiting = _waiting
        _waiting = []
        lock.unlock()
        waiting.forEach { $0() }
    }

    static let imageData: Data = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        let status = Self._status
        let cacheable = Self._cacheable
        let respond = { [weak self] in
            guard let self, let url = self.request.url else { return }
            let headers = cacheable
                ? ["Cache-Control": "public, max-age=86400", "Content-Type": "image/png"]
                : [:]
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            self.client?.urlProtocol(
                self, didReceive: response,
                cacheStoragePolicy: cacheable ? .allowed : .notAllowed
            )
            self.client?.urlProtocol(self, didLoad: Self.imageData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if Self._held {
            Self._waiting.append(respond)
            Self.lock.unlock()
        } else {
            Self.lock.unlock()
            DispatchQueue.global().async(execute: respond)
        }
    }

    override func stopLoading() {}
}

/// One load per avatar URL at a time, and no stale picture after invalidation.
@Suite(.serialized)
struct AvatarImageCacheLoadTests {

    private func makeCache() -> AvatarImageCache {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAvatarURLProtocol.self]
        configuration.urlCache = nil
        return AvatarImageCache(
            configuration: configuration,
            responseCache: URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, directory: nil)
        )
    }

    /// A configuration that *would* cache every response into `urlCache`, as
    /// `URLSession.shared` does into `URLCache.shared`.
    private func cachingConfiguration(into urlCache: URLCache) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [StubAvatarURLProtocol.self]
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return configuration
    }

    private func url(_ name: String = UUID().uuidString) -> URL {
        URL(string: "https://avatars.test.invalid/\(name).png")!
    }

    /// Poll until `condition` holds; the stub answers on another queue.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @Test
    func concurrentCallersShareOneRequest() async throws {
        StubAvatarURLProtocol.reset(held: true)
        let cache = makeCache()
        let target = url()

        async let first = cache.loadImage(for: target)
        async let second = cache.loadImage(for: target)
        await waitUntil { StubAvatarURLProtocol.requestCount >= 1 }
        #expect(cache.pendingLoadCount == 1)
        StubAvatarURLProtocol.release()

        _ = try await (first, second)
        #expect(StubAvatarURLProtocol.requestCount == 1)
        #expect(cache.pendingLoadCount == 0)
        #expect(cache.image(for: target) != nil)

        // And a later caller is served from the cache, not the network.
        _ = try await cache.loadImage(for: target)
        #expect(StubAvatarURLProtocol.requestCount == 1)
    }

    /// The window Astra flagged: the response is in, publication has not
    /// happened, and the avatar is removed. The picture must not land.
    @Test
    func invalidationDuringCompletionIsNotRepublished() async throws {
        StubAvatarURLProtocol.reset()
        let cache = makeCache()
        let target = url()
        cache.beforePublishingLoad = { [cache] loadedURL in
            cache.removeImage(for: loadedURL)
        }

        let image = try await cache.loadImage(for: target)
        #expect(image.size.width > 0, "the caller still gets what it asked for")
        #expect(cache.image(for: target) == nil)
        #expect(cache.pendingLoadCount == 0)

        cache.beforePublishingLoad = nil
        _ = try await cache.loadImage(for: target)
        #expect(StubAvatarURLProtocol.requestCount == 2, "the next request starts afresh")
        #expect(cache.image(for: target) != nil)
    }

    @Test
    func removalWhileInFlightDetachesTheOldLoad() async throws {
        StubAvatarURLProtocol.reset(held: true)
        let cache = makeCache()
        let target = url()

        let stale = Task { try await cache.loadImage(for: target) }
        await waitUntil { StubAvatarURLProtocol.requestCount == 1 }
        cache.removeImage(forURLString: target.absoluteString)
        #expect(cache.pendingLoadCount == 0)

        let fresh = Task { try await cache.loadImage(for: target) }
        await waitUntil { StubAvatarURLProtocol.requestCount == 2 }
        #expect(StubAvatarURLProtocol.requestCount == 2)
        StubAvatarURLProtocol.release()

        _ = try await stale.value
        _ = try await fresh.value
        #expect(cache.pendingLoadCount == 0)
        #expect(cache.image(for: target) != nil, "published by the fresh load only")
    }

    /// Control for the next test: with an ordinary caching session, this
    /// stub's response is stored by the transport itself, with no code of ours
    /// involved. That is the path that could resurrect a removed avatar.
    @Test
    func controlAnOrdinarySessionCachesTheStubResponseItself() async throws {
        StubAvatarURLProtocol.reset(cacheable: true)
        let urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, directory: nil)
        let target = url()
        _ = try await URLSession(configuration: cachingConfiguration(into: urlCache))
            .data(for: URLRequest(url: target))
        await waitUntil { urlCache.cachedResponse(for: URLRequest(url: target)) != nil }
        #expect(urlCache.cachedResponse(for: URLRequest(url: target)) != nil)
    }

    /// Given that same caching configuration and the very URL cache it reads
    /// from, a removal while the response is in flight must still leave
    /// nothing behind — neither in memory nor in the response cache.
    @Test
    func removalInFlightCannotBeResurrectedByTransportCaching() async throws {
        StubAvatarURLProtocol.reset(held: true, cacheable: true)
        let urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, directory: nil)
        let cache = AvatarImageCache(configuration: cachingConfiguration(into: urlCache), responseCache: urlCache)
        let target = url()

        let load = Task { try await cache.loadImage(for: target) }
        await waitUntil { StubAvatarURLProtocol.requestCount == 1 }
        cache.removeImage(for: target)
        StubAvatarURLProtocol.release()
        _ = try await load.value

        // Give any transport-side storage the same chance the control had.
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(urlCache.cachedResponse(for: URLRequest(url: target)) == nil)
        #expect(cache.image(for: target) == nil)
        #expect(cache.pendingLoadCount == 0)
    }

    /// Without a removal, the picture is still kept — through the explicit,
    /// token-checked store — so disabling transport caching loses nothing.
    @Test
    func anUninterruptedLoadIsStillKeptInTheResponseCache() async throws {
        StubAvatarURLProtocol.reset(cacheable: true)
        let urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, directory: nil)
        let cache = AvatarImageCache(configuration: cachingConfiguration(into: urlCache), responseCache: urlCache)
        let target = url()

        _ = try await cache.loadImage(for: target)
        #expect(urlCache.cachedResponse(for: URLRequest(url: target)) != nil)
        #expect(cache.image(for: target) != nil)
    }

    @Test
    func aFailedLoadIsNotCachedAndIsRetried() async {
        StubAvatarURLProtocol.reset(status: 500)
        let cache = makeCache()
        let target = url()

        await #expect(throws: (any Error).self) { _ = try await cache.loadImage(for: target) }
        #expect(cache.pendingLoadCount == 0)
        #expect(cache.image(for: target) == nil)

        await #expect(throws: (any Error).self) { _ = try await cache.loadImage(for: target) }
        #expect(StubAvatarURLProtocol.requestCount == 2)
    }

    /// The shared load outlives a caller that stopped wanting it — its picture
    /// still reaches the cache — but that caller must not paint it.
    @Test
    func aCancelledCallerPaintsNothing() async {
        StubAvatarURLProtocol.reset(held: true)
        let cache = makeCache()
        let target = url()

        let viewLoad = Task { await CachedAvatarImage.load(target, using: cache) }
        await waitUntil { StubAvatarURLProtocol.requestCount == 1 }
        viewLoad.cancel()
        StubAvatarURLProtocol.release()

        #expect(await viewLoad.value == .cancelled)
        await waitUntil { cache.image(for: target) != nil }
        #expect(cache.image(for: target) != nil)
    }

    @Test
    func aCurrentCallerGetsThePicture() async {
        StubAvatarURLProtocol.reset()
        let cache = makeCache()
        let outcome = await CachedAvatarImage.load(url(), using: cache)
        guard case .loaded = outcome else {
            Issue.record("expected a loaded image, got \(outcome)")
            return
        }
    }
}
