import SwiftUI

// MARK: - AsyncImageView
// Images are decoded off the main thread via ImageLoader (ImageIO downsampling).
// Remote images are cached in memory (NSCache 64 MB) and on disk (URLCache 128 MB).
// Max 4 concurrent network downloads — duplicate URL requests share one in-flight Task.
// ShimmerView removed: a static placeholder has zero GPU/animation overhead vs N infinite gradients.
struct AsyncImageView: View {
    let urlString: String?
    var imageData: Data? = nil
    var cornerRadius: CGFloat = Theme.Radius.image
    var contentMode: ContentMode = .fill

    @State private var loadedImage: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else if urlString == nil && imageData == nil {
                    placeholderView
                } else {
                    // Loading state — static fill, zero animation cost.
                    Color(.secondarySystemFill)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Decode stored image data off-main. Task id tracks meaningful data changes.
            .task(id: dataTaskID) {
                guard let data = imageData else { return }
                let img = await ImageLoader.shared.decode(data: data)
                guard !Task.isCancelled else { return }
                loadedImage = img
            }
            // Fetch remote URL. Cancelled automatically when id changes (new URL / cell reuse).
            .task(id: urlString) {
                guard imageData == nil else { return }   // stored data takes precedence
                guard let str = urlString, let url = URL(string: str) else {
                    loadedImage = nil
                    return
                }
                loadedImage = nil   // clear stale image while new one loads
                let img = await ImageLoader.shared.image(for: url)
                guard !Task.isCancelled else { return }
                loadedImage = img
            }
    }

    private var placeholderView: some View {
        ZStack {
            Color(.secondarySystemFill)
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
        }
    }

    /// Cheap task identity for stored data: hashes count + first 16 bytes (O(1) effectively).
    private var dataTaskID: Int? {
        guard let data = imageData else { return nil }
        var h = Hasher()
        h.combine(data.count)
        data.prefix(16).forEach { h.combine($0) }
        return h.finalize()
    }
}

#Preview {
    VStack(spacing: 16) {
        AsyncImageView(urlString: "https://picsum.photos/seed/preview/400/400")
            .frame(width: 160, height: 160)

        AsyncImageView(urlString: nil)
            .frame(width: 160, height: 160)

        AsyncImageView(urlString: "invalid-url")
            .frame(width: 160, height: 160)
    }
    .padding()
}
