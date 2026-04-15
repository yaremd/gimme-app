import Foundation

struct ItemMetadata: Sendable {
    let title: String
    let imageURL: URL?
    /// Additional product images found on the page (excluding the primary).
    let alternativeImageURLs: [URL]
    let price: Decimal?
    let currency: String?
    let description: String?
    /// Brand / retailer / manufacturer if detected.
    let brand: String?
    /// Color variant from URL query params or structured data.
    let color: String?
    /// Size variant from URL query params or structured data.
    let size: String?

    init(
        title: String,
        imageURL: URL? = nil,
        alternativeImageURLs: [URL] = [],
        price: Decimal? = nil,
        currency: String? = nil,
        description: String? = nil,
        brand: String? = nil,
        color: String? = nil,
        size: String? = nil
    ) {
        self.title = title
        self.imageURL = imageURL
        self.alternativeImageURLs = alternativeImageURLs
        self.price = price
        self.currency = currency
        self.description = description
        self.brand = brand
        self.color = color
        self.size = size
    }
}

protocol MetadataService: Sendable {
    func fetch(url: URL) async throws -> ItemMetadata
}

enum MetadataError: LocalizedError {
    case invalidURL
    case fetchFailed(String)
    case noDataFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL is not valid."
        case .fetchFailed(let msg): return "Failed to fetch metadata: \(msg)"
        case .noDataFound: return "No metadata found at this URL."
        }
    }
}
