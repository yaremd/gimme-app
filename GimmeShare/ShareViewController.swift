import UIKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Share Extension entry point.
/// Takes a shared link (or, failing that, a photo), leaves it in the App Group
/// for the app to pick up, shows a brief confirmation, then dismisses.
@objc(ShareViewController)
final class ShareViewController: UIViewController {

    nonisolated private static let appGroupID = "group.com.yaremchuk.app"
    nonisolated private static let pendingURLKey = "pendingSharedURL"

    private enum SharedContent: Sendable {
        case link(URL)
        /// A downsized JPEG, ready for the app.
        case photo(Data)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        nonisolated(unsafe) let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        Task { @MainActor in
            let content = await Self.extract(from: providers)
            presentConfirmation(Self.save(content))
        }
    }

    // MARK: - Extraction

    /// A web link wins over a photo: a product page carries better details than a picture of it.
    nonisolated private static func extract(from providers: [NSItemProvider]) async -> SharedContent? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await load(provider, UTType.url, { webURL(from: $0) }) {
                return .link(url)
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let jpeg = await load(provider, UTType.image, { downscaledJPEG(from: $0) }) {
                return .photo(jpeg)
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let url = await load(provider, UTType.plainText, { ($0 as? String)?.extractedURL }) {
                return .link(url)
            }
        }
        // Some apps share a photo as a file URL only.
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let jpeg = await load(provider, UTType.fileURL, { downscaledJPEG(from: $0) }) {
                return .photo(jpeg)
            }
        }
        return nil
    }

    /// Loads one representation and converts it to a Sendable value inside the
    /// provider's callback, so nothing non-Sendable crosses threads.
    nonisolated private static func load<T: Sendable>(
        _ provider: NSItemProvider,
        _ type: UTType,
        _ transform: @escaping @Sendable (NSSecureCoding?) -> T?
    ) async -> T? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { coding, _ in
                continuation.resume(returning: transform(coding))
            }
        }
    }

    nonisolated private static func webURL(from item: NSSecureCoding?) -> URL? {
        guard let url = item as? URL, url.scheme == "http" || url.scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    nonisolated private static func downscaledJPEG(from item: NSSecureCoding?) -> Data? {
        let source: CGImageSource?
        if let url = item as? URL, url.isFileURL {
            source = CGImageSourceCreateWithURL(url as CFURL, nil)
        } else if let data = item as? Data {
            source = CGImageSourceCreateWithData(data as CFData, nil)
        } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
            source = CGImageSourceCreateWithData(data as CFData, nil)
        } else {
            source = nil
        }
        return source.flatMap { SharedImageInbox.downscaledJPEG(from: $0) }
    }

    // MARK: - Hand-off

    private enum Outcome { case link, photo, nothing }

    /// The newest share replaces any older one still waiting for the app.
    private static func save(_ content: SharedContent?) -> Outcome {
        switch content {
        case .link(let url):
            SharedImageInbox.clear()
            UserDefaults(suiteName: appGroupID)?.set(url.absoluteString, forKey: pendingURLKey)
            return .link
        case .photo(let jpeg):
            return (try? SharedImageInbox.store(jpeg)) != nil ? .photo : .nothing
        case nil:
            return .nothing
        }
    }

    // MARK: - Confirmation UI

    private func presentConfirmation(_ outcome: Outcome) {
        let hosting = UIHostingController(
            rootView: ShareConfirmationView(
                outcome: outcome,
                onDone: { [weak self] in self?.finish() }
            )
        )
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)

        // Auto-dismiss after 1.4 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - SwiftUI confirmation view

    private struct ShareConfirmationView: View {
        let outcome: Outcome
        let onDone: () -> Void

        private var saved: Bool { outcome != .nothing }

        var body: some View {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: saved ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(saved ? Color(hex: "#3ECFAF") : .red)

                    Text(saved ? "Saved to Gimme" : "Nothing to save")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.system(.subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(40)
            }
        }

        private var message: String {
            switch outcome {
            case .link:    return "Open Gimme to finish adding the item."
            case .photo:   return "Open Gimme to identify it and finish adding."
            case .nothing: return "Share a link or a photo of the item."
            }
        }
    }
}

// MARK: - URL extraction from mixed text (mirrors Whish/Utilities/Extensions.swift)

private extension String {
    var extractedURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           (url.scheme == "http" || url.scheme == "https"),
           let host = url.host, !host.isEmpty {
            return url
        }
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range),
              let url = match.url,
              let scheme = url.scheme, scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

// MARK: - Color hex helper (extension local to this file)

private extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
