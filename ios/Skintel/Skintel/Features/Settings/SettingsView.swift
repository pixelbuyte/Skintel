import StoreKit
import SwiftUI
import SkintelCore

/// Design §17. Profile first (it drives every verdict), then membership, preferences,
/// data, and the destructive actions in verdict-red.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    @AppStorage(Haptics.preferenceKey) private var hapticsOn = true
    @State private var showEditProfile = false
    @State private var showManageSubs = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var deleteConfirmText = ""
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                Text("Settings").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, 44).padding(.top, SKSpace.md)

                profileCard

                group("Membership") {
                    row(title: "Skintel Pro", trailing: { SKChip(env.subscription.entitlement.tierLabel, tone: env.subscription.entitlement.isPro ? .good : .neutral) }) {
                        manageSubscription()
                    }
                    if let end = env.subscription.entitlement.periodEnd, env.subscription.entitlement.isPro {
                        info(env.subscription.subscription?.tier == .founding ? "Founding access until \(end.formatted(date: .abbreviated, time: .omitted))"
                             : "Renews \(end.formatted(date: .abbreviated, time: .omitted))")
                    }
                    if env.subscription.subscription?.isManagedByStripe == true {
                        info("Managed on skinstel.com")
                    }
                    row(title: "Restore purchases", trailing: { restoring ? AnyView(ProgressView().tint(SKColor.primary)) : AnyView(chevron) }, last: true) {
                        Task { await restore() }
                    }
                    if let restoreMessage { info(restoreMessage) }
                }

                group("Preferences") {
                    HStack {
                        Text("Haptics").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        Spacer()
                        Toggle("Haptics", isOn: $hapticsOn).labelsHidden().tint(SKColor.goodFg)
                    }
                    .padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
                    divider
                    row(title: "Camera & photo access", trailing: { chevron }, last: true) { CameraPermission.openSettings() }
                }

                group("Data") {
                    row(title: "Export my data", trailing: { exporting ? AnyView(ProgressView().tint(SKColor.primary)) : AnyView(chevron) }) { Task { await export() } }
                    if let exportError { info(exportError, tone: .bad) }
                    linkRow("Privacy policy", env.config.privacyURL)
                    linkRow("Terms", env.config.termsURL, last: true)
                }

                group("Account") {
                    info(env.session.user?.email ?? "")
                    Button { showSignOut = true } label: {
                        Text("Sign out").font(SKFont.sans(17, weight: .medium, relativeTo: .body)).foregroundStyle(SKColor.badFg)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button { showDelete = true } label: {
                        Text("Delete account").font(SKFont.sans(17, weight: .medium, relativeTo: .body)).foregroundStyle(SKColor.badFg)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                Text("Skintel \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · Not medical advice. Patterns, not prescriptions.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton().padding(.top, 2) }
        .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
        .manageSubscriptionsSheet(isPresented: $showManageSubs)
        .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        .confirmationDialog("Sign out of Skintel?", isPresented: $showSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await env.session.signOut() } }
        } message: { Text("Your shelf and journal stay in your account.") }
        .alert("Delete your account?", isPresented: $showDelete) {
            TextField("Type DELETE to confirm", text: $deleteConfirmText)
            Button("Delete everything", role: .destructive) { Task { await deleteAccount() } }
                .disabled(deleteConfirmText != "DELETE")
            Button("Cancel", role: .cancel) { deleteConfirmText = "" }
        } message: {
            Text("This permanently removes your products, ingredients, journal and subscription record. An active App Store subscription must be cancelled separately in your Apple ID settings.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(deleteError ?? "") }
        .overlay { if deleting { ZStack { Color.black.opacity(0.3).ignoresSafeArea(); ProgressView().tint(.white) } } }
        .task { await env.subscription.load() }
    }

    // MARK: Profile

    private var profileCard: some View {
        let user = env.session.user
        let profile = user?.skinProfile ?? SkinProfile()
        return SKCard {
            HStack(spacing: SKSpace.lg) {
                SKAvatar(name: user?.displayName ?? user?.email, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user?.displayName ?? "Add your name").font(SKFont.sans(20, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)
                    Text(profileLine(profile)).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(2)
                }
                Spacer()
                Button("Edit") { showEditProfile = true }.font(SKFont.sans(16, weight: .semibold)).foregroundStyle(SKColor.primary)
            }
        }
    }

    private func profileLine(_ p: SkinProfile) -> String {
        var parts: [String] = []
        if let t = p.skinType { parts.append(t.label) }
        if !p.concerns.isEmpty { parts.append(p.concerns.map { $0.label.lowercased() }.joined(separator: ", ")) }
        return parts.isEmpty ? "Skin profile not set — verdicts use your shelf only" : parts.joined(separator: " · ")
    }

    // MARK: Actions

    private func manageSubscription() {
        let ent = env.subscription.entitlement
        if !ent.isPro { openPaywall(.general); return }
        if env.subscription.subscription?.isManagedByApple == true { showManageSubs = true }
        // Stripe-managed rows show the "Managed on skinstel.com" line instead of a link.
    }

    private func restore() async {
        restoring = true; restoreMessage = nil
        defer { restoring = false }
        await env.subscriptionService.restore()
        restoreMessage = env.subscriptionService.lastMessage ?? (env.subscription.entitlement.isPro ? "Restored — you're on \(env.subscription.entitlement.tierLabel)." : nil)
    }

    private func export() async {
        exporting = true; exportError = nil
        defer { exporting = false }
        do {
            let data = try await env.api.exportData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("skintel-export-\(ISO8601.dayString(Date())).json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false; deleteConfirmText = "" }
        do {
            try await env.api.deleteAccount()
            env.session.signOutLocally()
        } catch {
            deleteError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    // MARK: Row helpers

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text(title).skLabelStyle().padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                .skCardShadow()
        }
    }

    private var divider: some View { Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, SKSpace.lg) }
    private var chevron: AnyView { AnyView(Text("›").font(SKFont.sans(18)).foregroundStyle(SKColor.muted)) }

    private func row<T: View>(title: String, @ViewBuilder trailing: () -> T, last: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(title).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    Spacer()
                    trailing()
                }
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !last { divider }
        }
    }

    private func linkRow(_ title: String, _ url: URL, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            Link(destination: url) {
                HStack {
                    Text(title).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
            }
            if !last { divider }
        }
    }

    private func info(_ text: String, tone: SKTone = .neutral) -> some View {
        VStack(spacing: 0) {
            Text(text).font(SKFont.caption).foregroundStyle(tone == .bad ? SKColor.badFg : SKColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SKSpace.lg).padding(.vertical, 10)
            divider
        }
    }
}

/// UIActivityViewController for the JSON export.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
