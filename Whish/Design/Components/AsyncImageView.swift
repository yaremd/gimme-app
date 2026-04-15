import SwiftUI

// MARK: - Shimmer effect
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemFill),
                Color(.systemBackground).opacity(0.8),
                Color(.systemFill),
            ],
            startPoint: .init(x: phase, y: 0.5),
            endPoint: .init(x: phase + 1, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

// MARK: - AsyncImageView with shimmer placeholder
struct AsyncImageView: View {
    let urlString: String?
    var imageData: Data? = nil
    var cornerRadius: CGFloat = Theme.Radius.image
    var contentMode: ContentMode = .fill

    var body: some View {
        // Color.clear fills the parent's proposed size and acts as a layout anchor.
        // The overlay constrains all image content to that exact box — including
        // AsyncImage, which ignores frame constraints when inside a transparent Group.
        Color.clear
            .overlay {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ShimmerView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: contentMode)
                                .transition(.opacity)
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderView: some View {
        ZStack {
            Color(.secondarySystemFill)
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
        }
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
