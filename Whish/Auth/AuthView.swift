import AuthenticationServices
import SwiftUI

/// Full-screen auth sheet. Presented from Settings when the user is not signed in.
struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordSent = false
    @FocusState private var focusedField: AuthField?
    @Environment(\.colorScheme) private var colorScheme

    private enum AuthField: Hashable {
        case email, password, confirmPassword
    }

    private enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Create Account"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                // Subtle background glow
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            Spacer(minLength: 20)
                            heroSection
                            appleSignInButton
                            orDivider
                            modePickerCard
                            fieldsCard
                            ctaButton
                                .id("ctaButton")
                            if mode == .signIn { forgotPasswordButton }
                            continueWithoutAccount
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) { _, field in
                        guard field != nil else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("ctaButton", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .glassCircleBackground()
                }
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                Button("Send Link") {
                    Task {
                        await auth.resetPassword(email: email)
                        forgotPasswordSent = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("We'll send a password reset link to your email.")
            }
            .alert("Link Sent", isPresented: $forgotPasswordSent) {
                Button("OK") {}
            } message: {
                Text("Check your inbox for the reset link.")
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
            .onChange(of: mode) { _, _ in
                auth.clearError()
                password = ""
                confirmPassword = ""
                isPasswordVisible = false
                isConfirmVisible = false
            }
        }
        .presentationCornerRadius(Theme.Radius.sheet)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image("GimmeIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 18, y: 7)

            VStack(spacing: 6) {
                Text(mode == .signIn ? "Welcome back" : "Create your account")
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(mode == .signIn
                     ? "Sign in to sync your lists across devices."
                     : "Your wishlists, everywhere.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Apple Sign In

    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = auth.prepareAppleNonce()
        } onCompletion: { result in
            Task { await auth.handleAppleResult(result) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .disabled(auth.isLoading)
    }

    private var orDivider: some View {
        HStack(spacing: Theme.Spacing.md) {
            Rectangle().fill(Theme.Colors.surfaceBorder).frame(height: 0.5)
            Text("or").font(.system(.caption)).foregroundStyle(Theme.Colors.textTertiary)
            Rectangle().fill(Theme.Colors.surfaceBorder).frame(height: 0.5)
        }
    }

    // MARK: - Mode picker

    private var modePickerCard: some View {
        HStack(spacing: 0) {
            ForEach(AuthMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(Theme.quickSpring) { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(mode == m ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            mode == m
                            ? Theme.Colors.accent.opacity(0.12)
                            : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Fields

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            // Email
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "envelope")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }
            .padding(Theme.Spacing.cardInner)

            fieldDivider

            // Password
            passwordField(
                placeholder: "Password",
                text: $password,
                isVisible: $isPasswordVisible,
                contentType: mode == .signUp ? .newPassword : .password,
                field: .password
            )

            // Confirm password (sign-up only)
            if mode == .signUp {
                fieldDivider
                passwordField(
                    placeholder: "Confirm Password",
                    text: $confirmPassword,
                    isVisible: $isConfirmVisible,
                    contentType: .newPassword,
                    field: .confirmPassword
                )
            }

            // Inline error
            if let err = auth.errorMessage, !err.isEmpty {
                fieldDivider
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
                               isVisible: Binding<Bool>, contentType: UITextContentType,
                               field: AuthField = .password) -> some View {
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
            .textContentType(contentType)
            .foregroundStyle(Theme.Colors.textPrimary)
            .focused($focusedField, equals: field)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.cardInner)
    }

    private var fieldDivider: some View {
        Rectangle()
            .fill(Theme.Colors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    // MARK: - CTA button

    private var ctaButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if auth.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(mode.rawValue)
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

    // MARK: - Forgot password

    private var forgotPasswordButton: some View {
        Button("Forgot password?") {
            showForgotPassword = true
        }
        .font(.system(.subheadline))
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: - Continue without account

    private var continueWithoutAccount: some View {
        Button { dismiss() } label: {
            Text("Continue without an account")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textTertiary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private var canSubmit: Bool {
        let validEmail = email.contains("@") && email.contains(".")
        let validPassword = password.count >= 6
        if mode == .signUp {
            return validEmail && validPassword && confirmPassword == password
        }
        return validEmail && validPassword
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await auth.signIn(email: email, password: password)
        case .signUp:
            await auth.signUp(email: email, password: password)
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthService())
}
