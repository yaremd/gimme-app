import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    private var modelContainer: ModelContainer { modelContext.container }
    @Environment(AuthService.self) private var auth
    @Environment(SyncService.self) private var syncService
    @Environment(PurchaseService.self) private var purchase

    @AppStorage("colorScheme")         private var colorSchemePreference = "system"
    @AppStorage("roundingEnabled")     private var roundingEnabled       = false
    @AppStorage("abbreviateNumbers")   private var abbreviateNumbers     = false
    @AppStorage("defaultCurrency")     private var defaultCurrency       = "USD"
    @AppStorage("notificationsOn")     private var notificationsOn       = false
    @AppStorage("fxLastUpdated")       private var fxLastUpdated: Double = 0

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "UAH"]

    @State private var isShowingAuth             = false
    @State private var isShowingSignOutConfirm   = false
    @State private var isShowingDeleteAccount     = false
    @State private var isShowingPaywall          = false

    @State private var isUpdatingRates           = false
    @State private var isShowingShareSheet       = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                List {
                    // ── Subscribe banner ─────────────────────────────
                    Section {
                        Button {
                            if !purchase.isPro { isShowingPaywall = true }
                        } label: {
                            proBanner
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            LinearGradient(
                                stops: purchase.isPro
                                    ? [
                                        .init(color: Theme.Colors.accent.opacity(0.11), location: 0),
                                        .init(color: Theme.Colors.accent.opacity(0.04), location: 1)
                                    ]
                                    : [
                                        .init(color: Theme.Colors.accent.opacity(0.22), location: 0),
                                        .init(color: Theme.Colors.accent.opacity(0.07), location: 1)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    // ── Account ──────────────────────────────────────
                    Section("Account") {
                        if auth.isSignedIn {
                            darkRow {
                                HStack(spacing: Theme.Spacing.md) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.Colors.accent.opacity(0.18))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "person")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.Colors.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(auth.userEmail ?? "Signed in")
                                            .font(.system(.subheadline, weight: .medium))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(purchase.isPro ? "Pro account" : "Free account")
                                            .font(.system(.caption))
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                    }
                                    Spacer()
                                }
                            }
                            darkRow {
                                Button {
                                    guard !syncService.isSyncing, let uid = auth.userID else { return }
                                    Task { await syncService.syncAll(container: modelContainer, userID: uid, force: true) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: syncService.isSyncing
                                              ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                                            .font(.system(size: 17))
                                            .frame(width: 22)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(syncService.isSyncing ? "Syncing…" : "Sync")
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                            if let error = syncService.syncError {
                                                Text(error)
                                                    .font(.system(.caption))
                                                    .foregroundStyle(.red.opacity(0.8))
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        if syncService.isSyncing {
                                            ProgressView().scaleEffect(0.7)
                                        } else if let last = syncService.lastSyncDate {
                                            Text(last.formatted(.relative(presentation: .named)))
                                                .font(.system(.caption))
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                        } else {
                                            Text("Not synced yet")
                                                .font(.system(.caption))
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            darkRow {
                                Button { isShowingDeleteAccount = true } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 17))
                                            .frame(width: 22)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Text("Danger Zone")
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            darkRow {
                                Button { isShowingAuth = true } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 17))
                                            .frame(width: 22)
                                            .foregroundStyle(Theme.Colors.accent)
                                        Text("Sign In / Create Account")
                                            .foregroundStyle(Theme.Colors.accent)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            darkRow {
                                HStack(spacing: 12) {
                                    Image(systemName: "icloud")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                    Text("Sync lists across devices when signed in.")
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                        .font(.system(.caption))
                                }
                            }
                        }
                    }

                    // ── Preferences ──────────────────────────────────
                    Section("Preferences") {
                        darkRow {
                            HStack(spacing: 12) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: 17))
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("Main Currency")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Menu {
                                    ForEach(currencies, id: \.self) { c in
                                        Button {
                                            withAnimation(Theme.quickSpring) { defaultCurrency = c }
                                        } label: {
                                            if defaultCurrency == c {
                                                Label(c, systemImage: "checkmark")
                                            } else {
                                                Text(c)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(currencyFlag(defaultCurrency))
                                        Text(defaultCurrency)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        darkRow {
                            HStack(spacing: 12) {
                                Image(systemName: "number.circle")
                                    .font(.system(size: 17))
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Rounding")
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        Toggle("", isOn: $roundingEnabled.animation(Theme.spring))
                                            .labelsHidden()
                                            .tint(Theme.Colors.accent)
                                    }
                                    Text("Display amounts without decimals")
                                        .font(.system(.caption))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                            }
                        }

                        darkRow {
                            HStack(spacing: 12) {
                                Image(systemName: "textformat.123")
                                    .font(.system(size: 17))
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Abbreviate Large Numbers")
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        Toggle("", isOn: $abbreviateNumbers.animation(Theme.spring))
                                            .labelsHidden()
                                            .tint(Theme.Colors.accent)
                                    }
                                    Text("Use compact format like 74.5k")
                                        .font(.system(.caption))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                            }
                        }

                        darkRow {
                            HStack(spacing: 12) {
                                Image(systemName: "paintpalette")
                                    .font(.system(size: 17))
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("Appearance")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Picker("", selection: $colorSchemePreference) {
                                    Text("System").tag("system")
                                    Text("Light").tag("light")
                                    Text("Dark").tag("dark")
                                }
                                .pickerStyle(.menu)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }

                    // ── Debug ────────────────────────────────────────
                    #if DEBUG
                    Section("Debug") {
                        darkRow {
                            Button {
                                purchase.debugTogglePro()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "hammer")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(.orange)
                                    Text(purchase.isPro ? "Set Free (debug)" : "Set Pro (debug)")
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        darkRow {
                            Button {
                                UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(.orange)
                                    Text("Reset Onboarding")
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    #endif

                    // ── Notifications ────────────────────────────────
                    Section("Notifications") {
                        darkRow {
                            HStack(spacing: 12) {
                                Image(systemName: "bell")
                                    .font(.system(size: 17))
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("Notifications")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Toggle("", isOn: $notificationsOn.animation(Theme.spring))
                                    .labelsHidden()
                                    .tint(Theme.Colors.accent)
                                    .onChange(of: notificationsOn) { _, newValue in
                                        if newValue {
                                            Task {
                                                let granted = await NotificationService.shared.requestPermission()
                                                if !granted { notificationsOn = false }
                                            }
                                        }
                                    }
                            }
                        }
                    }

                    // ── Links ────────────────────────────────────────
                    Section {
                        darkRow {
                            Button { requestReview() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "star")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("Rate & Review")
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        darkRow {
                            Button { isShowingShareSheet = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("Share Gimme")
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        darkRow {
                            Button {
                                if let url = URL(string: "mailto:hello@gimmelist.com?subject=Gimme%20Feedback") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 17))
                                        .frame(width: 22)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("Contact me")
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // ── Sign Out ─────────────────────────────────────
                    if auth.isSignedIn {
                        Section {
                            darkRow {
                                Button(role: .destructive) {
                                    isShowingSignOutConfirm = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 17))
                                            .frame(width: 22)
                                            .foregroundStyle(.red.opacity(0.85))
                                        Text("Sign Out")
                                            .foregroundStyle(.red.opacity(0.85))
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── Footer ───────────────────────────────────────
                    Section {
                        VStack(spacing: 8) {
                            Image("GimmeIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Image("GimmeLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 14)
                            Text("Made by Dmytro Yaremchuk © 2026")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Text("Version \(appVersion)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.textTertiary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                    .listRowBackground(Color.clear)
                    .listSectionSeparator(.hidden)
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.top, Theme.Spacing.cardGap, for: .scrollContent)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) { PaywallView().pageSheet() }
            .sheet(isPresented: $isShowingAuth) { AuthView().pageSheet() }
            .sheet(isPresented: $isShowingDeleteAccount) { DeleteAccountView().pageSheet() }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheetView(items: [
                    "Check out Gimme — the easiest way to create and share wishlists!",
                    URL(string: "https://gimmelist.com")!
                ])
                .pageSheet()
            }
            .onChange(of: auth.isSignedIn) { _, isSignedIn in
                if isSignedIn { dismiss() }
            }
            .alert("Sign Out?", isPresented: $isShowingSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your local data will be cleared from this device.")
            }
        }
        .preferredColorScheme(resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - Pro banner

    private var proBanner: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image("GimmeIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Image("GimmeLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 16)
                Text("Unlimited sharing, full stats, all widgets — one purchase, forever.")
                    .font(.system(.caption))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if purchase.isPro {
                Text("Pro ✓")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.Colors.accent, in: Capsule())
                    .shadow(color: Theme.Colors.accent.opacity(0.5), radius: 10, y: 4)
            } else {
                Text("Upgrade")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .shadow(color: Theme.Colors.accent.opacity(0.55), radius: 12, y: 5)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.7))
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Helpers

    private func darkRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowBackground(Theme.Colors.surface)
    }

    private func currencyFlag(_ code: String) -> String {
        switch code {
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "GBP": return "🇬🇧"
        case "JPY": return "🇯🇵"
        case "CAD": return "🇨🇦"
        case "AUD": return "🇦🇺"
        case "CHF": return "🇨🇭"
        case "CNY": return "🇨🇳"
        case "UAH": return "🇺🇦"
        default:    return "💱"
        }
    }

    private func updateRates() {
        isUpdatingRates = true
        Task {
            await CurrencyRateService.refresh()
            fxLastUpdated = UserDefaults.standard.double(forKey: "fxLastUpdated")
            isUpdatingRates = false
        }
    }
}

#Preview {
    SettingsView()
}
