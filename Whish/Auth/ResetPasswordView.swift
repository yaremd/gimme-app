import SwiftUI

struct ResetPasswordView: View {
    @Environment(AuthService.self) private var auth

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isNewVisible = false
    @State private var isConfirmVisible = false
    @State private var didSucceed = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case newPassword, confirm }

    private var canSubmit: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                if didSucceed {
                    successView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if auth.isPendingPasswordReset {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                        .scaleEffect(1.5)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            Spacer(minLength: 20)
                            headerSection
                            fieldsCard
                            ctaButton
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .transition(.opacity)
                }
            }
            .animation(Theme.quickSpring, value: didSucceed)
            .animation(Theme.quickSpring, value: auth.isPendingPasswordReset)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { auth.cancelPasswordRecovery() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Theme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.Colors.accent)

            VStack(spacing: 6) {
                Text("Password Updated")
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("You can now sign in with your new password.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Theme.Spacing.gridPadding)
        .task {
            try? await Task.sleep(for: .seconds(2))
            auth.dismissRecovery()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Colors.accent)

            VStack(spacing: 6) {
                Text("Set New Password")
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Choose a password with at least 6 characters.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Fields

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            passwordField(placeholder: "New Password", text: $newPassword,
                          isVisible: $isNewVisible, field: .newPassword)

            Rectangle().fill(Theme.Colors.surfaceBorder).frame(height: 0.5).padding(.leading, 52)

            passwordField(placeholder: "Confirm Password", text: $confirmPassword,
                          isVisible: $isConfirmVisible, field: .confirm)

            if let err = auth.errorMessage, !err.isEmpty {
                Rectangle().fill(Theme.Colors.surfaceBorder).frame(height: 0.5).padding(.leading, 52)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 20)
                    Text(err)
                        .font(.system(.caption))
                        .foregroundStyle(.red.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(Theme.Spacing.cardInner)
            }
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func passwordField(placeholder: String, text: Binding<String>,
                               isVisible: Binding<Bool>, field: Field) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock")
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 20)
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.newPassword)
            .foregroundStyle(Theme.Colors.textPrimary)
            .focused($focusedField, equals: field)

            Button { isVisible.wrappedValue.toggle() } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.cardInner)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task {
                await auth.updatePassword(newPassword)
                if auth.errorMessage == nil {
                    didSucceed = true
                }
            }
        } label: {
            ZStack {
                if auth.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Update Password")
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(canSubmit ? .white : Theme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .primaryGlassBackground(color: Theme.Colors.accent, isEnabled: canSubmit && !auth.isLoading)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || auth.isLoading)
    }
}
