import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Hand-off for photos shared into Gimme from other apps.
///
/// The Share Extension downsizes the shared image and drops one JPEG into the
/// App Group container; the app picks it up the next time it comes to the
/// foreground and opens Add Item with it. Compiled into both the app and the
/// GimmeShare extension (see project.yml).
enum SharedImageInbox {

    static let appGroupID = "group.com.yaremchuk.app"
    static let pendingKey = "pendingSharedImageAt"
    /// The extension's existing key for shared links. A newer share replaces an older one.
    static let pendingURLKey = "pendingSharedURL"
    static let fileName = "pending-shared-image.jpg"
    /// Long edge of the stored photo — the size Gimme keeps item photos at.
    static let maxPixelSize = 1200
    /// Older shares are dropped rather than popping up long after the fact.
    static let maxAge: TimeInterval = 24 * 60 * 60

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Stores `jpeg` as the pending shared photo and clears any pending link.
    static func store(_ jpeg: Data,
                      now: Date = .now,
                      defaults: UserDefaults? = SharedImageInbox.defaults,
                      fileURL: URL? = SharedImageInbox.fileURL) throws {
        guard let defaults, let fileURL else { throw CocoaError(.fileNoSuchFile) }
        try jpeg.write(to: fileURL, options: .atomic)
        defaults.set(now, forKey: pendingKey)
        defaults.removeObject(forKey: pendingURLKey)
    }

    /// Forgets a pending photo, e.g. when a link is shared after it.
    static func clear(defaults: UserDefaults? = SharedImageInbox.defaults,
                      fileURL: URL? = SharedImageInbox.fileURL) {
        defaults?.removeObject(forKey: pendingKey)
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    /// Returns the pending shared photo, if any, and removes it so it's handled once.
    static func consume(now: Date = .now,
                        defaults: UserDefaults? = SharedImageInbox.defaults,
                        fileURL: URL? = SharedImageInbox.fileURL) -> Data? {
        guard let defaults, let sharedAt = defaults.object(forKey: pendingKey) as? Date else { return nil }
        defaults.removeObject(forKey: pendingKey)
        guard let fileURL else { return nil }
        defer { try? FileManager.default.removeItem(at: fileURL) }
        guard now.timeIntervalSince(sharedAt) < maxAge else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Decodes at most `maxPixelSize` on the long edge straight from the source,
    /// so a 48 MP photo never has to fit in the extension's memory budget.
    static func downscaledJPEG(from source: CGImageSource,
                               maxPixelSize: Int = SharedImageInbox.maxPixelSize,
                               quality: Double = 0.8) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
