import AuthenticationServices
import SwiftUI

/// Design §06. Apple first (the native choice), then the email/password form the web
/// app uses, so the same account works in both places.
struct SignInView: View {
    @State var model: AuthViewModel
    @Environment(AppEnvironment.self) private var env
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SKAppMark(size: 64).padding(.top, SKSpace.xxl)

                Text(title)
                    .font(SKFont.hero)
                    .foregroundStyle(SKColor.ink)
                    .padding(.top, SKSpace.xl)
                Text(subtitle)
                    .font(SKFont.sans(17, relativeTo: .body))
                    .foregroundStyle(SKColor.muted)
                    .padding(.top, SKSpace.sm)

                if model.mode != .reset {
                    SignInWithAppleButton(.continue) { req in
                        model.prepareAppleRequest(req)
                    } onCompletion: { result in
                        Task { await model.handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                    .padding(.top, SKSpace.xl)
                    .disabled(model.isLoading)

                    orDivider.padding(.vertical, SKSpace.lg)
                }

                VStack(spacing: SKSpace.md) {
                    SKTextField(placeholder: "you@email.com", text: $model.email,
                                keyboard: .emailAddress, contentType: .emailAddress,
                                autocapitalization: .never, submitLabel: model.mode == .reset ? .send : .next) {
                        if model.mode == .reset { Task { await model.submit() } } else { focus = .password }
                    }
                    .focused($focus, equals: .email)

                    if model.mode != .reset {
                        SKTextField(placeholder: model.mode == .signUp ? "Password (8+ characters)" : "Password",
                                    text: $model.password, secure: true,
                                    contentType: model.mode == .signUp ? .newPassword : .password,
                                    submitLabel: .go) { Task { await model.submit() } }
                        .focused($focus, equals: .password)
                    }

                    if let error = model.error { SKInlineError(message: error) }
                    if let notice = model.notice {
                        Text(notice)
                            .font(SKFont.secondary).foregroundStyle(SKColor.goodFg)
                            .padding(SKSpace.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SKColor.goodBg, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                    }

                    SKButton(title: model.submitTitle, kind: .secondary, isLoading: model.isLoading) {
                        Task { await model.submit() }
                    }
                    .disabled(!model.canSubmit)
                }
                .padding(.top, model.mode == .reset ? SKSpace.xl : 0)

                modeSwitcher.padding(.top, SKSpace.lg)

                Spacer(minLength: SKSpace.xxl)

                legal
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { backButton }
        .animation(SKAnimation.ios(0.3), value: model.mode)
    }

    private var title: String {
        switch model.mode {
        case .signIn: "Welcome back."
        case .signUp: "Create your account."
        case .reset: "Reset your password."
        }
    }

    private var subtitle: String {
        switch model.mode {
        case .signIn: "Your shelf, routines and journal are synced."
        case .signUp: "Free to start. Your shelf syncs across devices."
        case .reset: "We'll email you a link to set a new one."
        }
    }

    private var orDivider: some View {
        HStack(spacing: SKSpace.md) {
            Rectangle().fill(SKColor.line).frame(height: 1)
            Text("or").font(SKFont.mono(11)).textCase(.uppercase).tracking(1.4).foregroundStyle(SKColor.muted)
            Rectangle().fill(SKColor.line).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var modeSwitcher: some View {
        HStack(spacing: SKSpace.lg) {
            switch model.mode {
            case .signIn:
                link("Create an account") { model.mode = .signUp }
                Spacer()
                link("Forgot password?") { model.mode = .reset }
            case .signUp:
                link("I already have an account") { model.mode = .signIn }
            case .reset:
                link("Back to sign in") { model.mode = .signIn }
            }
        }
    }

    private func link(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { model.error = nil; model.notice = nil; action() }) {
            Text(title).font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline)).foregroundStyle(SKColor.primary)
        }
        .buttonStyle(.plain)
    }

    private var legal: some View {
        (Text("By continuing you agree to the ")
         + Text("[Terms](\(env.config.termsURL.absoluteString))").underline()
         + Text(" and ")
         + Text("[Privacy Policy](\(env.config.privacyURL.absoluteString))").underline()
         + Text("."))
        .font(SKFont.caption)
        .foregroundStyle(SKColor.muted)
        .tint(SKColor.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    @Environment(\.dismiss) private var dismiss
    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SKColor.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, SKSpace.sm)
        .accessibilityLabel("Back")
    }
}
