import UIKit
import ImageIO

/// Off-main-thread image loader with memory + disk caching and bounded concurrency.
///
/// - Memory cache: NSCache, 64 MB cost limit (auto-evicted under memory pressure).
/// - Disk cache:   URLCache, 128 MB, shared URLSession cache policy.
/// - Concurrency:  Max 4 simultaneous network downloads. Duplicate URL requests are
///                 coalesced — a second call for the same URL awaits the first task.
/// - Decode:       All JPEG/PNG decode happens on the actor's background executor via
///                 ImageIO downsampling, never on the main thread.
actor ImageLoader {
    static let shared = ImageLoader()

    private let memory: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    private let urlSession: URLSession = {
        let dir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("com.yaremchuk.app.images")
        let urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            directory: dir
        )
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = urlCache
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()

    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var slots = 4
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Public

    /// Returns a downsampled UIImage for the given URL.
    /// Reads from NSCache first; falls back to URLSession (which itself checks URLCache).
    /// Concurrent calls for the same URL share a single in-flight Task.
    func image(for url: URL, maxPixels: CGFloat = 800) async -> UIImage? {
        let key = cacheKey(url: url, maxPixels: maxPixels)
        if let hit = memory.object(forKey: key as NSString) { return hit }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> {
            await acquireSlot()
            defer { releaseSlot() }
            do {
                let (data, _) = try await urlSession.data(from: url)
                guard !Task.isCancelled else { return nil }
                let img = Self.downsample(data: data, maxPixels: maxPixels)
                if let img {
                    memory.setObject(img, forKey: key as NSString, cost: data.count)
                }
                return img
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight.removeValue(forKey: key)
        return result
    }

    /// Decodes stored Data off the main thread, downsampled to maxPixels.
    func decode(data: Data, maxPixels: CGFloat = 800) -> UIImage? {
        Self.downsample(data: data, maxPixels: maxPixels)
    }

    // MARK: - Concurrency slot management

    private func acquireSlot() async {
        if slots > 0 { slots -= 1; return }
        await withCheckedContinuation { cont in waiters.append(cont) }
    }

    private func releaseSlot() {
        if waiters.isEmpty { slots += 1 } else { waiters.removeFirst().resume() }
    }

    // MARK: - ImageIO downsampling

    private func cacheKey(url: URL, maxPixels: CGFloat) -> String {
        "\(url.absoluteString)|\(Int(maxPixels))"
    }

    /// Decodes and resizes in a single ImageIO pass — no double-decode, no main thread.
    private static func downsample(data: Data, maxPixels: CGFloat) -> UIImage? {
        let sourceOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, sourceOpts) else {
            return UIImage(data: data)
        }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cgImg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImg)
    }
}
