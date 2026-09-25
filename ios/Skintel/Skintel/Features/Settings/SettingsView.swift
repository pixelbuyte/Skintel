import StoreKit
import SwiftUI
import UserNotifications
import SkintelCore

/// You: a profile the person shapes up top, then settings in layers. Everyday choices live
/// one tap down in Personalization; account, data and the destructive actions live in
/// Account & data instead of on the first screen.
struct SettingsView: View {
    /// True when hosted as the You tab: no back button, no room reserved for one.
    var isRoot = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SKAvatarLook.key) private var avatarLook = 0
    @AppStorage(AskModel.key) private var askModel: AskModel = .luna
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab
    @AppStorage(Haptics.preferenceKey) private var hapticsOn = true
    @AppStorage(RoutineReminders.amOnKey) private var amOn = false
    @AppStorage(RoutineReminders.pmOnKey) private var pmOn = false
    @AppStorage(RoutineReminders.checkInOnKey) private var checkInOn = false
    @State private var showEditProfile = false
    @State private var showPersonalization = false
    @State private var showAccount = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                Text(isRoot ? "You" : "Settings").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, isRoot ? 0 : 44).padding(.top, SKSpace.md)

                profileHero
                stats

                SettingsGroup(title: "Personalize") {
                    SettingsRow(icon: "drop", title: "Skin profile", subtitle: skinSummary) { showEditProfile = true }
                    SettingsRow(icon: "sparkles", title: "Ask Skintel",
                                subtitle: "\(askModel.name) · \(assistantPlacement == AssistantPlacement.tab ? "in the tab bar" : "top of Today")") {
                        showPersonalization = true
                    }
                    SettingsRow(icon: "bell", title: "Reminders", subtitle: reminderSummary) { showPersonalization = true }
                    SettingsRow(icon: "slider.horizontal.3", title: "Feel", subtitle: hapticsOn ? "Haptics on" : "Haptics off", last: true) {
                        showPersonalization = true
                    }
                }

                membershipCard

                HStack(spacing: SKSpace.md) {
                    SKDrop("DropPrivacy", size: 56)
                    Text("Your shelf, journal and check-ins belong to your account. Delete them any time in Account & data.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
                .padding(.horizontal, 4)

                SettingsGroup(title: "Account") {
                    SettingsRow(title: "Account & data", subtitle: env.session.user?.email) { showAccount = true }
                    SettingsLinkRow(title: "Privacy policy", url: env.config.privacyURL)
                    SettingsLinkRow(title: "Terms", url: env.config.termsURL, last: true)
                }

                Text("Skintel \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · Not medical advice. Patterns, not prescriptions.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { if !isRoot { BackButton().padding(.top, 2) } }
        .navigationDestination(isPresented: $showPersonalization) { PersonalizationView() }
        .navigationDestination(isPresented: $showAccount) { AccountDataView() }
        .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
        .task {
            await env.subscription.load()
            await env.journal.load()
        }
    }

    // MARK: Profile

    private var profileHero: some View {
        let user = env.session.user
        return VStack(spacing: SKSpace.sm) {
            Button(action: shuffleAvatar) {
                SKGeneratedAvatar(look: avatarLook, size: 88)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SKColor.primary)
                            .frame(width: 30, height: 30)
                            .background(SKColor.cream, in: Circle())
                            .overlay(Circle().stroke(SKColor.line))
                            .skSoftShadow()
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(SKPressStyle(scale: 0.94))
            .accessibilityLabel("Shuffle your avatar")
            Text("Tap your avatar to shuffle it").font(SKFont.caption).foregroundStyle(SKColor.muted)
            VStack(spacing: 3) {
                Text(user?.displayName ?? "Add your name").font(SKFont.sans(22, weight: .semibold, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                Text(profileLine(user?.skinProfile ?? SkinProfile())).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .multilineTextAlignment(.center)
            }
            Button { showEditProfile = true } label: {
                Text("Edit profile")
                    .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.primary)
                    .padding(.horizontal, SKSpace.lg)
                    .frame(height: 38)
                    .background(SKColor.blush, in: Capsule())
            }
            .buttonStyle(SKPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(SKColor.line))
        .skCardShadow()
    }

    private var stats: some View {
        HStack(spacing: SKSpace.sm) {
            statTile("\(env.journal.streak)", "day streak")
            statTile("\(env.journal.entries.count)", env.journal.entries.count == 1 ? "check-in" : "check-ins")
            statTile("\(env.products.products.count)", "on your shelf")
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(SKFont.stat).foregroundStyle(SKColor.ink)
            Text(label).font(SKFont.caption).foregroundStyle(SKColor.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SKSpace.md)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
        .accessibilityElement(children: .combine)
    }

    private var membershipCard: some View {
        let ent = env.subscription.entitlement
        let founding = env.subscription.subscription?.tier == .founding
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("Membership").skLabelStyle().padding(.leading, 4)
            HStack(spacing: SKSpace.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ent.isPro ? (founding ? "Founding member" : "Skintel Pro") : "Skintel Free")
                        .font(SKFont.sans(17, weight: .semibold, relativeTo: .headline))
                    Text(membershipLine(ent: ent, founding: founding))
                        .font(SKFont.secondary).opacity(0.85)
                }
                Spacer(minLength: 0)
                Button {
                    if ent.isPro { showAccount = true } else { openPaywall(.general) }
                } label: {
                    Text(ent.isPro ? "Manage" : "Upgrade")
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(SKColor.cream.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(SKColor.cream.opacity(0.35)))
                }
                .buttonStyle(SKPressStyle())
            }
            .foregroundStyle(SKColor.cream)
            .padding(SKSpace.lg)
            .background(LinearGradient(colors: [Color(hex: 0xB2634F), SKColor.primary, SKColor.primaryPressed],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .skPrimaryGlow(strength: 0.25)
        }
    }

    private func membershipLine(ent: Entitlement, founding: Bool) -> String {
        guard ent.isPro else { return "Scanning, Ask Skintel and journal analysis" }
        guard let end = ent.periodEnd else { return "Active" }
        let date = end.formatted(date: .abbreviated, time: .omitted)
        return founding ? "Access until \(date)" : "Renews \(date)"
    }

    private var skinSummary: String {
        let p = env.session.user?.skinProfile ?? SkinProfile()
        guard let t = p.skinType else { return "Not set yet" }
        return p.concerns.isEmpty ? t.label : "\(t.label) · \(p.concerns.count) concern\(p.concerns.count == 1 ? "" : "s")"
    }

    private var reminderSummary: String {
        let on = [amOn ? "AM" : nil, pmOn ? "PM" : nil, checkInOn ? "check-in" : nil].compactMap { $0 }
        return on.isEmpty ? "Off" : on.joined(separator: " · ")
    }

    private func profileLine(_ p: SkinProfile) -> String {
        var parts: [String] = []
        if let t = p.skinType { parts.append("\(t.label) skin") }
        if !p.concerns.isEmpty { parts.append(p.concerns.map { $0.label.lowercased() }.joined(separator: ", ")) }
        return parts.isEmpty ? "Skin profile not set — verdicts use your shelf only" : parts.joined(separator: " · ")
    }

    private func shuffleAvatar() {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : Animation.spring(duration: 0.35, bounce: 0.3)) {
            avatarLook = SKGeneratedAvatar.shuffled(from: avatarLook)
        }
    }
}

// MARK: - Personalization

private struct PersonalizationView: View {
    @AppStorage(AskModel.key) private var askModel: AskModel = .luna
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab
    @AppStorage(Haptics.preferenceKey) private var hapticsOn = true
    @AppStorage(RoutineReminders.amOnKey) private var amOn = false
    @AppStorage(RoutineReminders.amTimeKey) private var amMinutes = 7 * 60 + 30
    @AppStorage(RoutineReminders.pmOnKey) private var pmOn = false
    @AppStorage(RoutineReminders.pmTimeKey) private var pmMinutes = 21 * 60 + 45
    @AppStorage(RoutineReminders.checkInOnKey) private var checkInOn = false
    @AppStorage(RoutineReminders.checkInTimeKey) private var checkInMinutes = 20 * 60
    @AppStorage(CheckInPrompt.enabledKey) private var askOnOpen = true
    @State private var tipsReset = false

    var body: some View {
        SettingsPage(title: "Personalization") {
            SettingsGroup(title: "Ask Skintel · default model",
                          footer: "You can still switch in a chat. New chats start with this one.") {
                ForEach(Array(AskModel.allCases.enumerated()), id: \.element) { index, m in
                    SettingsChoiceRow(icon: m.icon, title: m.name, subtitle: m.blurb, selected: askModel == m,
                                      last: index == AskModel.allCases.count - 1) {
                        askModel = m
                    }
                }
            }

            SettingsGroup(title: "Where Ask Skintel lives") {
                SettingsChoiceRow(title: "Tab bar", subtitle: "Its own tab, always one tap away",
                                  selected: assistantPlacement == AssistantPlacement.tab) {
                    assistantPlacement = AssistantPlacement.tab
                }
                SettingsChoiceRow(title: "Top of Today", subtitle: "A button on Today; Shelf takes the tab",
                                  selected: assistantPlacement == AssistantPlacement.corner, last: true) {
                    assistantPlacement = AssistantPlacement.corner
                }
            }

            HStack(spacing: SKSpace.md) {
                SKDrop("DropSunscreen", size: 56)
                Text("A morning reminder is a good nudge to finish with sunscreen.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            .padding(.horizontal, 4)

            SettingsGroup(title: "Reminders", footer: "Reminders are scheduled on this iPhone and repeat daily.") {
                reminderRow("Morning routine", on: $amOn, minutes: $amMinutes)
                reminderRow("Night routine", on: $pmOn, minutes: $pmMinutes)
                reminderRow("Skin check-in", on: $checkInOn, minutes: $checkInMinutes)
                Toggle(isOn: $askOnOpen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask when I open Skintel").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        Text("Once in the morning and once in the evening").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                }
                .tint(SKColor.primary)
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 10)
            }

            SettingsGroup(title: "Feel") {
                Toggle(isOn: $hapticsOn) {
                    Text("Haptics").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                }
                .tint(SKColor.primary)
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 10)
                SettingsDivider()
                SettingsRow(title: "Camera & photo access", last: true) { CameraPermission.openSettings() }
            }

            SettingsGroup(title: "Tips", footer: "Each screen's one-time tip shows again the next time you open it.") {
                SettingsRow(title: "Reset tips", subtitle: tipsReset ? "Tips will show again" : "Show the tip on each screen again",
                            showsChevron: false, last: true, trailing: {
                    if tipsReset {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(SKColor.primary)
                            .accessibilityHidden(true)
                    }
                }) {
                    HintID.resetAll()
                    tipsReset = true
                    Haptics.success()
                }
            }
        }
        .onChange(of: reminderSignature) { _, _ in scheduleReminders() }
    }

    private var reminderSignature: String {
        "\(amOn)\(amMinutes)|\(pmOn)\(pmMinutes)|\(checkInOn)\(checkInMinutes)"
    }

    private func scheduleReminders() {
        RoutineReminders.apply(am: amOn ? amMinutes : nil, pm: pmOn ? pmMinutes : nil, checkIn: checkInOn ? checkInMinutes : nil)
    }

    private func reminderRow(_ title: String, on: Binding<Bool>, minutes: Binding<Int>, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: on) {
                Text(title).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
            }
            .tint(SKColor.primary)
            .padding(.horizontal, SKSpace.lg).padding(.vertical, 10)
            if on.wrappedValue {
                DatePicker("Time", selection: timeBinding(minutes), displayedComponents: .hourAndMinute)
                    .font(SKFont.secondary)
                    .foregroundStyle(SKColor.muted)
                    .tint(SKColor.primary)
                    .padding(.horizontal, SKSpace.lg).padding(.bottom, 10)
            }
            if !last { SettingsDivider() }
        }
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}

/// Daily local reminders for the routine and the skin check-in. Nothing leaves the device.
enum RoutineReminders {
    static let amOnKey = "reminder.am.on"
    static let amTimeKey = "reminder.am.minutes"
    static let pmOnKey = "reminder.pm.on"
    static let pmTimeKey = "reminder.pm.minutes"
    static let checkInOnKey = "reminder.checkin.on"
    static let checkInTimeKey = "reminder.checkin.minutes"

    private struct Item: Sendable {
        let id: String
        let minutes: Int
        let title: String
        let body: String
    }

    private static let ids = ["skintel.reminder.am", "skintel.reminder.pm", "skintel.reminder.checkin"]

    /// Replaces every Skintel reminder with the enabled ones (`nil` = off), asking for
    /// permission the first time one is turned on.
    static func apply(am: Int?, pm: Int?, checkIn: Int?) {
        var wanted: [Item] = []
        if let am { wanted.append(Item(id: ids[0], minutes: am, title: "Morning routine", body: "Your AM steps are ready on Today.")) }
        if let pm { wanted.append(Item(id: ids[1], minutes: pm, title: "Night routine", body: "Time for your PM routine.")) }
        if let checkIn { wanted.append(Item(id: ids[2], minutes: checkIn, title: "How's your skin today?", body: "One tap on Today logs it.")) }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        guard !wanted.isEmpty else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let center = UNUserNotificationCenter.current()
            for item in wanted {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                var when = DateComponents()
                when.hour = item.minutes / 60
                when.minute = item.minutes % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}

// MARK: - Account & data

private struct AccountDataView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

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
        SettingsPage(title: "Account & data") {
            SettingsGroup {
                HStack {
                    Text("Email").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    Spacer(minLength: SKSpace.sm)
                    Text(env.session.user?.email ?? "").font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                }
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
            }

            SettingsGroup(title: "Membership") {
                SettingsRow(title: "Skintel Pro", trailing: {
                    SKChip(env.subscription.entitlement.tierLabel, tone: env.subscription.entitlement.isPro ? .good : .neutral)
                }) { manageSubscription() }
                if let end = env.subscription.entitlement.periodEnd, env.subscription.entitlement.isPro {
                    SettingsInfo(text: env.subscription.subscription?.tier == .founding
                                 ? "Founding access until \(end.formatted(date: .abbreviated, time: .omitted))"
                                 : "Renews \(end.formatted(date: .abbreviated, time: .omitted))")
                }
                if env.subscription.subscription?.isManagedByStripe == true {
                    SettingsInfo(text: "Managed on skinstel.com")
                }
                SettingsRow(title: "Restore purchases", last: restoreMessage == nil, trailing: {
                    if restoring { ProgressView().tint(SKColor.primary) }
                }) {
                    Task { await restore() }
                }
                if let restoreMessage { SettingsInfo(text: restoreMessage, last: true) }
            }

            SettingsGroup(title: env.subscription.entitlement.isPro ? "Your Pro benefits" : "What Pro adds",
                          footer: "Tap one to watch it work.") {
                ProBenefitsList().padding(.horizontal, SKSpace.lg).padding(.vertical, 4)
            }

            SettingsGroup(title: "Your data") {
                SettingsRow(title: "Export my data", subtitle: "Shelf, journal and scans as a file", trailing: {
                    if exporting { ProgressView().tint(SKColor.primary) }
                }) {
                    Task { await export() }
                }
                if let exportError { SettingsInfo(text: exportError, tone: .bad) }
                SettingsLinkRow(title: "Privacy policy", url: env.config.privacyURL)
                SettingsLinkRow(title: "Terms", url: env.config.termsURL, last: true)
            }

            SKButton(title: "Sign out", kind: .secondary) { showSignOut = true }

            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text("Delete account").font(SKFont.sans(16, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.badFg)
                Text("Permanently removes your shelf, journal and subscription record. An App Store subscription is cancelled separately in your Apple ID settings.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                Button { showDelete = true } label: {
                    Text("Delete account…")
                        .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.badFg)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .overlay(Capsule().stroke(SKColor.badFg.opacity(0.4)))
                }
                .buttonStyle(SKPressStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SKSpace.lg)
            .background(SKColor.badBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, SKSpace.md)
        }
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
}

// MARK: - Building blocks

/// A pushed settings screen: serif title beside the back button, scrolling content.
private struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                Text(title).font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .padding(.leading, 44).padding(.top, SKSpace.md)
                content
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton().padding(.top, 2) }
    }
}

/// A labelled card of rows.
private struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            if let title { Text(title).skLabelStyle().padding(.leading, 4) }
            VStack(spacing: 0) { content }
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(SKColor.line))
                .skCardShadow()
            if let footer {
                Text(footer).font(SKFont.caption).foregroundStyle(SKColor.muted).padding(.horizontal, 4)
            }
        }
    }
}

private struct SettingsDivider: View {
    var body: some View { Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, SKSpace.lg) }
}

/// A tappable row: optional icon tile, title and subtitle, then a trailing view or chevron.
private struct SettingsRow<Trailing: View>: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil
    var showsChevron = true
    var last = false
    let trailing: Trailing
    let action: () -> Void

    init(icon: String? = nil, title: String, subtitle: String? = nil, showsChevron: Bool = true, last: Bool = false,
         @ViewBuilder trailing: () -> Trailing, action: @escaping () -> Void) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.showsChevron = showsChevron; self.last = last
        self.trailing = trailing(); self.action = action
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: SKSpace.md) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SKColor.primary)
                            .frame(width: 34, height: 34)
                            .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: SKSpace.sm)
                    trailing
                    if showsChevron {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                    }
                }
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !last { SettingsDivider() }
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String? = nil, title: String, subtitle: String? = nil, showsChevron: Bool = true, last: Bool = false,
         action: @escaping () -> Void) {
        self.init(icon: icon, title: title, subtitle: subtitle, showsChevron: showsChevron, last: last,
                  trailing: { EmptyView() }, action: action)
    }
}

/// One option in a single-choice list, with a Skintel-brown check on the chosen one.
private struct SettingsChoiceRow: View {
    var icon: String? = nil
    let title: String
    let subtitle: String
    let selected: Bool
    var last = false
    let action: () -> Void

    var body: some View {
        SettingsRow(icon: icon, title: title, subtitle: subtitle, showsChevron: false, last: last, trailing: {
            if selected {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(SKColor.primary)
            }
        }) {
            guard !selected else { return }
            Haptics.selection()
            action()
        }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let url: URL
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            Link(destination: url) {
                HStack {
                    Text(title).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
                .padding(.horizontal, SKSpace.lg).padding(.vertical, 14)
            }
            if !last { SettingsDivider() }
        }
    }
}

private struct SettingsInfo: View {
    let text: String
    var tone: SKTone = .neutral
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            Text(text).font(SKFont.caption).foregroundStyle(tone == .bad ? SKColor.badFg : SKColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SKSpace.lg).padding(.vertical, 10)
            if !last { SettingsDivider() }
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
