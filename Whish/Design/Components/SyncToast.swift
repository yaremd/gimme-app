import SwiftUI

/// Compact pill overlay showing sync status. Only appears on manual sync (pull-to-refresh).
struct SyncToast: View {
    let isSyncing: Bool
    let lastSyncDate: Date?
    @State private var showCompleted = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isSyncing {
                pill {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing...")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if showCompleted {
                pill {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All synced")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.quickSpring, value: isSyncing)
        .animation(Theme.quickSpring, value: showCompleted)
        .onChange(of: isSyncing) { wasSyncing, syncing in
            if wasSyncing && !syncing {
                showCompleted = true
                Haptics.success()
                dismissTask?.cancel()
                dismissTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    showCompleted = false
                }
            }
        }
    }

    private func pill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .font(.system(.caption, weight: .medium))
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
