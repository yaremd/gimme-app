import Foundation

struct MockMetadataService: MetadataService {
    func fetch(url: URL) async throws -> ItemMetadata {
        try await Task.sleep(for: .milliseconds(800))

        let host = url.host ?? "example.com"
        let seed = host.hashValue

        let mockItems: [ItemMetadata] = [
            ItemMetadata(
                title: "Sony WH-1000XM5 Wireless Headphones",
                imageURL: URL(string: "https://picsum.photos/seed/headphones/400/400"),
                alternativeImageURLs: [
                    URL(string: "https://picsum.photos/seed/headphones2/400/400")!,
                    URL(string: "https://picsum.photos/seed/headphones3/400/400")!,
                ],
                price: Decimal(349.99),
                currency: "USD",
                description: "Industry-leading noise canceling with two processors.",
                brand: "Sony",
                color: "Black",
                size: nil
            ),
            ItemMetadata(
                title: "Apple AirPods Pro (2nd generation)",
                imageURL: URL(string: "https://picsum.photos/seed/airpods/400/400"),
                price: Decimal(249.00),
                currency: "USD",
                description: "Active Noise Cancellation and Adaptive Transparency.",
                brand: "Apple"
            ),
            ItemMetadata(
                title: "Kindle Paperwhite",
                imageURL: URL(string: "https://picsum.photos/seed/kindle/400/400"),
                price: Decimal(139.99),
                currency: "USD",
                description: "6.8\" display with adjustable warm light.",
                brand: "Amazon"
            ),
            ItemMetadata(
                title: "Lego Architecture Skyline",
                imageURL: URL(string: "https://picsum.photos/seed/lego/400/400"),
                price: Decimal(59.99),
                currency: "USD",
                description: "Build your favorite city skyline.",
                brand: "LEGO"
            ),
        ]

        let index = abs(seed) % mockItems.count
        return mockItems[index]
    }
}
