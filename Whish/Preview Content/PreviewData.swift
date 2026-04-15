import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema([WishList.self, WishItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let c = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Preview ModelContainer failed to initialize")
        }
        insertSampleData(into: c.mainContext)
        return c
    }()

    private static func insertSampleData(into context: ModelContext) {
        // --- Birthday List ---
        let birthday = WishList(
            name: "Birthday",
            emoji: "🎂",
            colorHex: "#FFB3BA"
        )
        context.insert(birthday)

        let item1 = WishItem(
            title: "Sony WH-1000XM5 Headphones",
            notes: "Black color preferred",
            url: "https://www.sony.com/en/products/headphones",
            imageURL: "https://picsum.photos/seed/headphones/400/400",
            price: Decimal(349.99),
            currency: "USD",
            priority: .high,
            isPurchased: false,
            list: birthday
        )

        let item2 = WishItem(
            title: "Kindle Paperwhite (16GB)",
            notes: "With the warm light option",
            url: "https://amazon.com/kindle",
            imageURL: "https://picsum.photos/seed/kindle/400/400",
            price: Decimal(139.99),
            currency: "USD",
            priority: .medium,
            isPurchased: true,
            list: birthday
        )

        let item3 = WishItem(
            title: "Laneige Lip Sleeping Mask",
            url: "https://laneige.com",
            imageURL: "https://picsum.photos/seed/beauty/400/400",
            price: Decimal(24.00),
            currency: "USD",
            priority: .low,
            isPurchased: false,
            list: birthday
        )

        birthday.items = [item1, item2, item3]
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)

        // --- Tech Gear List ---
        let tech = WishList(
            name: "Tech Gear",
            emoji: "💻",
            colorHex: "#B3D9FF"
        )
        context.insert(tech)

        let item4 = WishItem(
            title: "Apple AirPods Pro (2nd Gen)",
            url: "https://apple.com/airpods-pro",
            imageURL: "https://picsum.photos/seed/airpods/400/400",
            price: Decimal(249.00),
            currency: "USD",
            priority: .high,
            isPurchased: false,
            list: tech
        )

        let item5 = WishItem(
            title: "Keychron K2 Mechanical Keyboard",
            notes: "Brown switches",
            imageURL: "https://picsum.photos/seed/keyboard/400/400",
            price: Decimal(89.00),
            currency: "USD",
            priority: .medium,
            isPurchased: false,
            list: tech
        )

        let item6 = WishItem(
            title: "Anker MagSafe Power Bank",
            imageURL: "https://picsum.photos/seed/powerbank/400/400",
            price: Decimal(45.99),
            currency: "USD",
            priority: .low,
            isPurchased: true,
            list: tech
        )

        let item7 = WishItem(
            title: "MX Master 3S Mouse",
            imageURL: "https://picsum.photos/seed/mouse/400/400",
            price: Decimal(99.99),
            currency: "USD",
            priority: .medium,
            isPurchased: false,
            list: tech
        )

        tech.items = [item4, item5, item6, item7]
        context.insert(item4)
        context.insert(item5)
        context.insert(item6)
        context.insert(item7)

        // --- Home List ---
        let home = WishList(
            name: "Home",
            emoji: "🏠",
            colorHex: "#B3FFD1"
        )
        context.insert(home)

        let item8 = WishItem(
            title: "Philips Hue Starter Kit",
            notes: "For the living room",
            imageURL: "https://picsum.photos/seed/lights/400/400",
            price: Decimal(199.99),
            currency: "USD",
            priority: .medium,
            isPurchased: false,
            list: home
        )

        let item9 = WishItem(
            title: "MUJI Aroma Diffuser",
            imageURL: "https://picsum.photos/seed/diffuser/400/400",
            price: Decimal(89.00),
            currency: "USD",
            priority: .low,
            isPurchased: false,
            list: home
        )

        let item10 = WishItem(
            title: "Nespresso Vertuo Coffee Maker",
            imageURL: "https://picsum.photos/seed/coffee/400/400",
            price: Decimal(199.00),
            currency: "USD",
            priority: .high,
            isPurchased: false,
            list: home
        )

        home.items = [item8, item9, item10]
        context.insert(item8)
        context.insert(item9)
        context.insert(item10)

        // --- Books List ---
        let books = WishList(
            name: "Books",
            emoji: "📚",
            colorHex: "#FFE4B3"
        )
        context.insert(books)

        let item11 = WishItem(
            title: "Atomic Habits by James Clear",
            imageURL: "https://picsum.photos/seed/atomichabits/400/400",
            price: Decimal(14.99),
            currency: "USD",
            priority: .high,
            isPurchased: true,
            list: books
        )

        let item12 = WishItem(
            title: "The Design of Everyday Things",
            notes: "Revised edition",
            imageURL: "https://picsum.photos/seed/designbook/400/400",
            price: Decimal(18.00),
            currency: "USD",
            priority: .medium,
            isPurchased: false,
            list: books
        )

        let item13 = WishItem(
            title: "Project Hail Mary by Andy Weir",
            imageURL: "https://picsum.photos/seed/scifibook/400/400",
            price: Decimal(16.99),
            currency: "USD",
            priority: .medium,
            isPurchased: false,
            list: books
        )

        books.items = [item11, item12, item13]
        context.insert(item11)
        context.insert(item12)
        context.insert(item13)

        try? context.save()
    }

    // Single items for focused previews
    static var sampleList: WishList {
        WishList(name: "Birthday", emoji: "🎂", colorHex: "#FFB3BA")
    }

    static var sampleItem: WishItem {
        WishItem(
            title: "Sony WH-1000XM5 Headphones",
            notes: "Black color preferred",
            url: "https://sony.com",
            imageURL: "https://picsum.photos/seed/headphones/400/400",
            price: Decimal(349.99),
            currency: "USD",
            priority: .high
        )
    }
}
