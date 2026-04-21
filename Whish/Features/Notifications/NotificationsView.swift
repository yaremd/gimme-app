import SwiftUI
import UserNotifications

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - Model

struct NotificationEvent: Codable, Identifiable {
    let id: UUID
    let listID: UUID
    let itemID: UUID
    let listName: String
    let itemTitle: String
    var isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listID    = "list_id"
        case itemID    = "item_id"
        case listName  = "list_name"
        case itemTitle = "item_title"
        case isRead    = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - ViewModel

private struct ItemImageDTO: Decodable {
    let id: UUID
    let imageURL: String?
    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
    }
}

@Observable
@MainActor
final class NotificationsViewModel {
    var events: [NotificationEvent] = []
    var itemImages: [UUID: String] = [:]
    var isLoading = false

    var unreadCount: Int { events.filter { !$0.isRead }.count }

    func load(ownerID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [NotificationEvent] = try await supabase
                .from("notification_events")
                .select()
                .eq("owner_id", value: ownerID)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            events = fetched

            let ids = fetched.map { $0.itemID.uuidString }
            if !ids.isEmpty {
                let dtos: [ItemImageDTO] = try await supabase
                    .from("wish_items")
                    .select("id, image_url")
                    .in("id", values: ids)
                    .execute()
                    .value
                var map: [UUID: String] = [:]
                for dto in dtos { if let url = dto.imageURL { map[dto.id] = url } }
                itemImages = map
            }
        } catch {
            print("[Notifications] Load failed: \(error)")
        }
    }

    func markAllRead(ownerID: String) async {
        guard unreadCount > 0 else { return }
        // Optimistic update — clear dots immediately
        for i in events.indices { events[i].isRead = true }
        // Clear the app icon badge
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        do {
            try await supabase
                .from("notification_events")
                .update(["is_read": true])
                .eq("owner_id", value: ownerID)
                .eq("is_read", value: false)
                .execute()
        } catch {
            print("[Notifications] Mark-read failed: \(error)")
        }
    }
}

// MARK: - View

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    let viewModel: NotificationsViewModel
    var onSelectItem: ((UUID) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.events.isEmpty {
                        ProgressView()
                            .tint(Theme.Colors.accent)
                    } else if viewModel.events.isEmpty {
                        emptyState
                    } else {
                        eventsList
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .task {
                guard let uid = auth.userID else { return }
                await viewModel.markAllRead(ownerID: uid)
            }
        }
    }

    // MARK: Events list

    private var eventsList: some View {
        List {
            ForEach(viewModel.events) { event in
                NotificationEventRow(event: event, itemImageURL: viewModel.itemImages[event.itemID]) {
                    onSelectItem?(event.itemID)
                    dismiss()
                }
                .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.cardGap / 2,
                        leading: Theme.Spacing.gridPadding,
                        bottom: Theme.Spacing.cardGap / 2,
                        trailing: Theme.Spacing.gridPadding
                    ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, Theme.Spacing.md, for: .scrollContent)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "bell")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.Colors.accent)
            }

            VStack(spacing: 6) {
                Text("No activity yet")
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("When someone reserves an item from\nyour shared lists, you'll see it here.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct NotificationEventRow: View {
    let event: NotificationEvent
    var itemImageURL: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: { rowContent }
            .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: Theme.Spacing.md) {

            // Item image or fallback gift bubble
            if let url = itemImageURL, !url.isEmpty {
                AsyncImageView(urlString: url, imageData: nil, cornerRadius: 10)
                    .frame(width: 52, height: 52)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.Colors.accent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Text("🎁")
                        .font(.system(size: 22))
                }
            }

            // Text stack
            VStack(alignment: .leading, spacing: 3) {
                Text("Someone reserved **\(event.itemTitle)**")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text("from your \(event.listName) list")
                    .font(.system(.caption))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(event.createdAt.relativeFormatted)
                    .font(.system(.caption2))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 1)
            }

            Spacer()

            // Unread dot
            if !event.isRead {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(Theme.Spacing.cardInner)
        .glassCardBackground()
    }
}
