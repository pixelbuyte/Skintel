import AuthenticationServices
import SwiftUI

/// Design §06. Apple first (the native choice), then the email/password form the web
/// app uses, so the same account works in both places.
struct SignInView: View {
    @State var model: AuthViewModel
    @Environment(AppEnvironment.self) private var env
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
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

                    googleButton
                        .padding(.top, SKSpace.md)
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

                if model.mode == .signUp {
                    freeIncludes.padding(.top, SKSpace.xl)
                }

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

    private var freeIncludes: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("YOUR FREE ACCOUNT INCLUDES").font(SKFont.label).tracking(1.2).foregroundStyle(SKColor.muted)
            ForEach(FreeBenefit.allCases) { b in
                HStack(spacing: SKSpace.sm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SKColor.goodFg)
                        .frame(width: 22, height: 22)
                        .background(SKColor.goodBg, in: Circle())
                        .accessibilityHidden(true)
                    Text(b.title).font(SKFont.sans(15, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                }
            }
            Text("Scanning, Ask Skintel and trigger tracking come with Skintel+.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
    }

    /// Same height and radius as the Apple button; cream surface, ink border and text.
    private var googleButton: some View {
        Button {
            Task { await model.signInWithGoogle(using: webAuthenticationSession) }
        } label: {
            HStack(spacing: SKSpace.sm) {
                GoogleGMark(size: 18)
                Text("Continue with Google")
                    .font(SKFont.button)
                    .foregroundStyle(SKColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.ink, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
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

/// Google "G" drawn from simple shapes (no image asset): four trimmed ring segments plus
/// the blue crossbar. Brand colours come from `SKColor.GoogleMark`.
private struct GoogleGMark: View {
    var size: CGFloat

    var body: some View {
        let stroke = size * 0.22
        // Circle trim runs clockwise from 3 o'clock; the gap sits at the top right.
        ZStack {
            segment(0.0, 0.125, SKColor.GoogleMark.blue, stroke)
            segment(0.125, 0.44, SKColor.GoogleMark.green, stroke)
            segment(0.44, 0.6, SKColor.GoogleMark.yellow, stroke)
            segment(0.6, 0.875, SKColor.GoogleMark.red, stroke)
            Rectangle()
                .fill(SKColor.GoogleMark.blue)
                .frame(width: size * 0.48, height: stroke)
                .offset(x: size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func segment(_ from: CGFloat, _ to: CGFloat, _ color: Color, _ stroke: CGFloat) -> some View {
        Circle()
            .inset(by: stroke / 2)
            .trim(from: from, to: to)
            .stroke(color, lineWidth: stroke)
    }
}
