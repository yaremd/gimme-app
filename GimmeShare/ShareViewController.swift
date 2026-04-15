import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Share Extension entry point.
/// Extracts the shared URL, stores it in the App Group UserDefaults,
/// shows a brief confirmation, then dismisses.
@objc(ShareViewController)
final class ShareViewController: UIViewController {

    nonisolated private static let appGroupID = "group.com.yaremchuk.app"
    nonisolated private static let pendingURLKey = "pendingSharedURL"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        extractURL { [weak self] url in
            guard let self else { return }
            if let url {
                UserDefaults(suiteName: Self.appGroupID)?
                    .set(url.absoluteString, forKey: Self.pendingURLKey)
            }
            DispatchQueue.main.async { self.presentConfirmation(found: url != nil) }
        }
    }

    // MARK: - URL extraction

    private func extractURL(completion: @escaping @Sendable (URL?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        for item in items {
            for provider in item.attachments ?? [] {
                // Prefer a native URL type
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { coding, _ in
                        completion(coding as? URL)
                    }
                    return
                }
                // Fallback: plain text that looks like a URL
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { coding, _ in
                        if let text = coding as? String,
                           let url = text.extractedURL {
                            completion(url)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                }
            }
        }
        completion(nil)
    }

    // MARK: - Confirmation UI

    private func presentConfirmation(found: Bool) {
        let hosting = UIHostingController(
            rootView: ShareConfirmationView(
                found: found,
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
}

// MARK: - SwiftUI confirmation view

private struct ShareConfirmationView: View {
    let found: Bool
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: found ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(found ? Color(hex: "#3ECFAF") : .red)

                Text(found ? "Saved to Gimme" : "No URL found")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)

                if found {
                    Text("Open Gimme to finish adding the item.")
                        .font(.system(.subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(40)
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
