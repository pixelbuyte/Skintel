import SwiftUI
import SkintelCore

/// Recommend.tsx: goal + budget → `/api/recommend`, which builds avoid/prefer lists from
/// the shelf server-side. Options are the web's six goals and three budget presets.
struct RecommendView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    private struct Goal: Identifiable { let id: String; let label: String; let icon: String }
    private let goals: [Goal] = [
        .init(id: "cleanser", label: "Cleanser", icon: "drop"),
        .init(id: "moisturizer", label: "Moisturizer", icon: "square.stack"),
        .init(id: "serum", label: "Serum", icon: "flask"),
        .init(id: "sunscreen", label: "Sunscreen", icon: "sun.max"),
        .init(id: "toner", label: "Toner", icon: "wind"),
        .init(id: "exfoliant", label: "Exfoliant", icon: "flame"),
    ]
    private struct Budget: Identifiable { let id: String; let label: String; let max: Int; let hint: String }
    private let budgets: [Budget] = [
        .init(id: "drugstore", label: "Everyday", max: 20, hint: "≤ $20"),
        .init(id: "mid", label: "Mid", max: 50, hint: "≤ $50"),
        .init(id: "luxury", label: "Luxury", max: 100, hint: "≤ $100"),
    ]

    @State private var goal = "moisturizer"
    @State private var budget = "mid"
    @State private var notes = ""
    @State private var result: Loadable<RecommendResult> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find a product").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, 44)
                    Text("Picks that avoid what broke you out and lean on what worked.")
                        .font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                }
                .padding(.top, SKSpace.md)

                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("I'm looking for a")
                    let cols = [GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm)]
                    LazyVGrid(columns: cols, spacing: SKSpace.sm) {
                        ForEach(goals) { g in
                            Button { goal = g.id; Haptics.selection() } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: g.icon).font(.system(size: 18, weight: .medium))
                                    Text(g.label).font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                                }
                                .foregroundStyle(goal == g.id ? SKColor.primary : SKColor.ink)
                                .frame(maxWidth: .infinity).frame(height: 72)
                                .background(goal == g.id ? SKColor.blush : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(goal == g.id ? SKColor.primary : SKColor.line, lineWidth: goal == g.id ? 1.5 : 1))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(goal == g.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("Budget")
                    HStack(spacing: SKSpace.sm) {
                        ForEach(budgets) { b in
                            Button { budget = b.id; Haptics.selection() } label: {
                                VStack(spacing: 4) {
                                    Text(b.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                                    Text(b.hint).font(SKFont.dataSmall)
                                }
                                .foregroundStyle(budget == b.id ? SKColor.primary : SKColor.ink)
                                .frame(maxWidth: .infinity).frame(height: 64)
                                .background(budget == b.id ? SKColor.blush : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(budget == b.id ? SKColor.primary : SKColor.line, lineWidth: budget == b.id ? 1.5 : 1))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(budget == b.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    SKFieldLabel("Anything else")
                    SKTextEditor(placeholder: "Fragrance-free, no silicones, for under makeup…", text: $notes, minHeight: 80)
                }

                if case .failed(let e) = result { SKInlineError(message: e.userMessage) }
                SKButton(title: "Find products", systemImage: "wand.and.stars", isLoading: result.isLoading) { Task { await run() } }

                if case .loaded(let r) = result {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text("Picks for you").font(SKFont.section).foregroundStyle(SKColor.ink)
                        if r.recommendations.isEmpty {
                            Text("Nothing fit those constraints. Try a wider budget.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                        ForEach(r.recommendations) { rec in
                            SKCard {
                                VStack(alignment: .leading, spacing: SKSpace.sm) {
                                    HStack(alignment: .top, spacing: SKSpace.md) {
                                        SKProductMark(name: rec.productName, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            if let b = rec.brand { Text(b).skLabelStyle() }
                                            Text(rec.productName).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                                        }
                                        Spacer()
                                        if let p = rec.priceRange { Text(p).font(SKFont.dataSmall).foregroundStyle(SKColor.muted) }
                                    }
                                    if let k = rec.keyIngredients?.values, !k.isEmpty {
                                        FlowLayout(spacing: 6) { ForEach(k.prefix(6), id: \.self) { SKChip($0, tone: .good) } }
                                    }
                                    if let why = rec.whyItFits, !why.isEmpty { Text(why).font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                                    if let w = rec.watchOuts, !w.isEmpty, w.lowercased() != "none" {
                                        Text("Watch: \(w)").font(SKFont.secondary).foregroundStyle(SKColor.cautionFg)
                                    }
                                }
                            }
                        }
                        Text("Suggestions are generated from your shelf's history. Check the ingredient list on the real packaging before buying.")
                            .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                }
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton().padding(.top, 2) }
    }

    private func run() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.recommend); return }
        result = .loading
        let b = budgets.first { $0.id == budget }
        do {
            result = .loaded(try await env.api.recommend(RecommendRequest(goal: goal, budget: budget, maxPrice: b?.max, count: 5,
                                                                          notes: notes.isEmpty ? nil : String(notes.prefix(500)))))
            Haptics.success()
        } catch let e as APIError {
            if e.requiresPaywall { openPaywall(.recommend); result = .idle } else { result = .failed(e) }
        } catch { result = .failed(.network(error.localizedDescription)) }
    }
}

// MARK: - Ask Skintel

/// Where Ask Skintel lives, chosen in You › Preferences: its own tab, or a button at the
/// top of Today (with Shelf taking the tab slot back).
enum AssistantPlacement {
    static let key = "assistant.placement"
    static let tab = "tab"
    static let corner = "corner"
}

/// Ask Skintel's two models, switched with the toggle in the composer. The raw value is
/// the name the server maps to a provider model; the app never sends provider model ids.
enum AskModel: String, CaseIterable, Identifiable {
    case luna, sol
    static let key = "assistant.model"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .luna: "Luna"
        case .sol: "Sol"
        }
    }

    var blurb: String {
        switch self {
        case .luna: "Fastest for everyday questions"
        case .sol: "Most thorough for ingredients and reactions"
        }
    }

    var icon: String {
        switch self {
        case .luna: "moon.stars.fill"
        case .sol: "sun.max.fill"
        }
    }
}

/// Two-model switch in the Ask Skintel composer: the selected side is a Skintel-brown pill
/// that slides across, like the AM/PM toggle on Today.
private struct AskModelToggle: View {
    @Binding var selection: AskModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AskModel.allCases) { m in
                let on = selection == m
                Button {
                    guard !on else { return }
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : SKAnimation.ios(0.3)) { selection = m }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon).font(.system(size: 11, weight: .semibold))
                        Text(m.name).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    }
                    .foregroundStyle(on ? SKColor.cream : SKColor.muted)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background {
                        if on {
                            Capsule().fill(SKColor.primary).matchedGeometryEffect(id: "askModel", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m.name)
                .accessibilityHint(m.blurb)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(SKColor.neutralChip, in: Capsule())
    }
}

struct AssistantMessage: Codable, Identifiable, Sendable, Equatable {
    enum Role: String, Codable, Sendable { case user, assistant, notice, upsell }
    var id = UUID()
    var role: Role
    var text: String
}

/// A saved Ask Skintel conversation.
struct AssistantConversation: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var title: String
    var updatedAt: Date
    var messages: [AssistantMessage]
}

/// Chat history, kept on this device only (like the routine) and cleared on sign-out.
@MainActor
@Observable
final class AssistantStore {
    private(set) var conversations: [AssistantConversation] = []
    private let fileURL: URL
    private static let maxConversations = 50

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("assistant.v1.json")
        load()
    }

    func save(_ conversation: AssistantConversation) {
        var list = conversations.filter { $0.id != conversation.id }
        list.append(conversation)
        list.sort { $0.updatedAt > $1.updatedAt }
        conversations = Array(list.prefix(Self.maxConversations))
        persist()
    }

    func delete(id: UUID) {
        conversations.removeAll { $0.id == id }
        persist()
    }

    func reset() {
        conversations = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([AssistantConversation].self, from: data) else { return }
        conversations = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}

/// The Skintel assistant. Suggested questions have written answers (free, instant, and
/// personalised from the shelf and routine where that is accurate). Typed questions go to
/// the model through `/api/assistant` for Pro accounts; the key never leaves the server.
struct AssistantView: View {
    /// False when hosted as a tab: there is nothing to close.
    var showsClose = true

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var conversationID = UUID()
    @State private var messages: [AssistantMessage] = []
    @State private var draft = ""
    @State private var isAnswering = false
    @State private var showHistory = false
    @State private var paywall: PaywallReason?
    @AppStorage(AskModel.key) private var askModel: AskModel = .luna
    @FocusState private var inputFocused: Bool

    private static let upsellText = "Typing your own questions is part of Skintel Pro. The suggested questions stay free."

    private var isPro: Bool { env.subscription.entitlement.isPro }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: SKSpace.lg) {
                        if messages.isEmpty {
                            welcome
                        } else {
                            ForEach(messages) { m in
                                AssistantBubble(message: m).id(m.id)
                            }
                            if isAnswering && messages.last?.role == .user {
                                TypingDots()
                            }
                            if !isAnswering && messages.last?.role == .upsell {
                                SKButton(title: "See Skintel Pro", kind: .secondary, fullWidth: false) { paywall = .general }
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .skPagePadding()
                    .padding(.top, SKSpace.md)
                    .padding(.bottom, SKSpace.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: messages.last?.text) { _, _ in scrollToEnd(proxy) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .skPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsClose {
                        Button("Close") { dismiss() }.font(SKFont.bodyMedium)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Ask Skintel").font(SKFont.navTitle).foregroundStyle(SKColor.ink)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .disabled(isAnswering)
                        .accessibilityLabel("Chat history")
                    Button { startNewChat() } label: { Image(systemName: "square.and.pencil") }
                        .disabled(messages.isEmpty || isAnswering)
                        .accessibilityLabel("New chat")
                }
            }
        }
        .tint(SKColor.primary)
        .sheet(isPresented: $showHistory) {
            AssistantHistoryView { open($0) }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $paywall) { PaywallView(reason: $0) }
    }

    // MARK: Empty state

    private var welcome: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                AssistantAvatar(size: 44)
                Text("What can I help with?").font(SKFont.hero).foregroundStyle(SKColor.ink)
                Text("Ask about your routine, ingredients or a reaction. Answers use your shelf and routine.")
                    .font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted)
            }
            .padding(.top, SKSpace.xl)
            VStack(spacing: SKSpace.sm) {
                ForEach(AssistantPrompt.allCases) { p in
                    Button { ask(p) } label: { suggestionCard(p) }
                        .buttonStyle(SKPressStyle())
                }
            }
        }
    }

    private func suggestionCard(_ p: AssistantPrompt) -> some View {
        HStack(spacing: SKSpace.md) {
            Image(systemName: p.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SKColor.primary)
                .frame(width: 36, height: 36)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(p.question)
                .font(SKFont.sans(16, weight: .medium, relativeTo: .body))
                .foregroundStyle(SKColor.ink)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SKColor.muted)
        }
        .padding(SKSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
    }

    // MARK: Composer

    private var remainingPrompts: [AssistantPrompt] {
        AssistantPrompt.allCases.filter { p in !messages.contains { $0.role == .user && $0.text == p.question } }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnswering
    }

    private var composer: some View {
        VStack(spacing: SKSpace.sm) {
            if !messages.isEmpty && !remainingPrompts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SKSpace.sm) {
                        ForEach(remainingPrompts) { p in
                            Button { ask(p) } label: {
                                Text(p.question)
                                    .font(SKFont.sans(14, weight: .medium, relativeTo: .subheadline))
                                    .foregroundStyle(SKColor.ink)
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .frame(height: 38)
                                    .background(SKColor.cream, in: Capsule())
                                    .overlay(Capsule().stroke(SKColor.line))
                            }
                            .buttonStyle(SKPressStyle())
                            .disabled(isAnswering)
                        }
                    }
                    .padding(.horizontal, SKSpace.lg)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Ask about your skin or products", text: $draft)
                    .font(SKFont.body)
                    .foregroundStyle(SKColor.ink)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                HStack(spacing: SKSpace.sm) {
                    AskModelToggle(selection: $askModel)
                    Spacer(minLength: 0)
                    Button(action: sendDraft) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(SKColor.cream)
                            .frame(width: 36, height: 36)
                            .background(canSend ? SKColor.primary : SKColor.muted.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send")
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .skGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: false, fallback: SKColor.cream)
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(SKColor.line))
            .padding(.horizontal, SKSpace.lg)
            Group {
                if isPro {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(askModel.name)
                                .font(SKFont.sans(12, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(SKColor.primary)
                            Text("· \(askModel.blurb)")
                        }
                        Text("Answers can be wrong. Skintel isn't a doctor.")
                    }
                } else {
                    Text("Suggested questions are free. Typing your own is part of Skintel Pro.")
                }
            }
            .font(SKFont.caption)
            .foregroundStyle(SKColor.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SKSpace.xl)
        }
        .padding(.top, SKSpace.sm)
        .padding(.bottom, SKSpace.sm)
        .background {
            LinearGradient(colors: [SKColor.bg.opacity(0), SKColor.bg], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Conversation

    private func ask(_ p: AssistantPrompt) {
        guard !isAnswering else { return }
        inputFocused = false
        Haptics.tap()
        messages.append(AssistantMessage(role: .user, text: p.question))
        deliver(answer(for: p), role: .assistant)
    }

    private func sendDraft() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return }
        draft = ""
        Haptics.tap()
        messages.append(AssistantMessage(role: .user, text: question))
        guard isPro else {
            deliver(Self.upsellText, role: .upsell)
            return
        }
        var turns: [SkintelAPI.AssistantTurn] = []
        for m in messages {
            if m.role == .user { turns.append(SkintelAPI.AssistantTurn(role: "user", content: m.text)) }
            if m.role == .assistant { turns.append(SkintelAPI.AssistantTurn(role: "assistant", content: m.text)) }
        }
        let am = names(.am)
        let pm = names(.pm)
        let api = env.api
        let model = askModel.rawValue
        isAnswering = true
        Task {
            do {
                let reply = try await api.askAssistant(messages: turns, amRoutine: am, pmRoutine: pm, model: model)
                deliver(reply, role: .assistant, alreadyWaited: true)
            } catch let e as APIError {
                if e.requiresPaywall {
                    deliver(Self.upsellText, role: .upsell, alreadyWaited: true)
                } else if case .server(let status, _) = e, status == 503 {
                    deliver("Ask Skintel isn't switched on yet. Try one of the suggested questions for now.", role: .notice, alreadyWaited: true)
                } else {
                    deliver(e.userMessage, role: .notice, alreadyWaited: true)
                }
            } catch {
                deliver(error.localizedDescription, role: .notice, alreadyWaited: true)
            }
        }
    }

    /// A short typing pause (skipped when the network already made them wait), then answers
    /// are revealed word by word the way a live assistant streams. Reduce Motion shows the
    /// text at once. Every finished exchange is saved to history.
    private func deliver(_ text: String, role: AssistantMessage.Role, alreadyWaited: Bool = false) {
        isAnswering = true
        let reduce = reduceMotion
        let chatID = conversationID
        Task {
            if !alreadyWaited {
                try? await Task.sleep(for: .milliseconds(reduce ? 150 : 700))
            }
            guard chatID == conversationID else {
                isAnswering = false
                return
            }
            if reduce || role != .assistant {
                messages.append(AssistantMessage(role: role, text: text))
            } else {
                let message = AssistantMessage(role: role, text: "")
                messages.append(message)
                var shown = ""
                for (i, word) in text.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
                    shown += i == 0 ? String(word) : " " + String(word)
                    if let index = messages.firstIndex(where: { $0.id == message.id }) { messages[index].text = shown }
                    try? await Task.sleep(for: .milliseconds(22))
                }
            }
            isAnswering = false
            saveConversation()
        }
    }

    private func saveConversation() {
        guard let first = messages.first(where: { $0.role == .user }) else { return }
        env.assistant.save(AssistantConversation(id: conversationID,
                                                 title: String(first.text.prefix(80)),
                                                 updatedAt: Date(),
                                                 messages: messages))
    }

    private func startNewChat() {
        conversationID = UUID()
        messages = []
        draft = ""
    }

    private func open(_ conversation: AssistantConversation) {
        conversationID = conversation.id
        messages = conversation.messages
        draft = ""
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        if reduceMotion {
            proxy.scrollTo(last.id, anchor: .bottom)
        } else {
            withAnimation(SKAnimation.ios(0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    // MARK: Written answers

    private func answer(for p: AssistantPrompt) -> String {
        switch p {
        case .order:
            return orderAnswer()
        case .retinolVitaminC:
            return "They're usually best kept apart rather than layered together:\n\n• **Vitamin C in the morning.** It pairs well with sunscreen.\n• **Retinol at night.** Sunlight breaks it down.\n\nIf you're new to retinol, start with 2–3 nights a week and build up slowly. Skip exfoliating acids on retinol nights, and wear sunscreen every morning, because retinol makes skin more sensitive to the sun."
        case .irritated:
            return irritatedAnswer()
        case .patchTest:
            return "The American Academy of Dermatology suggests:\n\n1. Put a small amount on a spot where it won't be washed off, like the bend of your elbow.\n2. Do this twice a day for 7 to 10 days.\n3. If there's no reaction, it's likely fine to use on your face.\n\nTry one new product at a time, about a week apart. Otherwise you can't tell which one caused a reaction."
        }
    }

    private func names(_ slot: RoutineStore.Slot) -> [String] {
        env.routine.ids(slot).compactMap { env.products.product(id: $0)?.product.productName }
    }

    private func numbered(_ items: [String]) -> String {
        items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    private func orderAnswer() -> String {
        let am = names(.am)
        let pm = names(.pm)
        if am.isEmpty && pm.isEmpty {
            return "An order that works for most routines:\n\n1. Cleanser\n2. Toner or essence\n3. Serums and treatments\n4. Moisturiser\n5. Sunscreen, in the morning\n\nAdd your products to a routine and Skintel keeps them in this order on Today."
        }
        var parts = ["Here's your routine as you've set it up:"]
        if !am.isEmpty { parts.append("**Morning**\n" + numbered(am)) }
        if !pm.isEmpty { parts.append("**Night**\n" + numbered(pm)) }
        parts.append("The rule of thumb is thinnest to thickest: cleanser, toner, serums, moisturiser, then sunscreen last in the morning. You can reorder steps in Routine.")
        return parts.joined(separator: "\n\n")
    }

    private func irritatedAnswer() -> String {
        var s = "Keep tonight simple:\n\n• A gentle cleanser\n• A plain, fragrance-free moisturiser\n• Pause strong actives for a couple of nights: retinoids, exfoliating acids and vitamin C\n\nIf you started something new in the last two weeks, that's the first thing to suspect. Log how your skin feels on Today so Skintel can spot a pattern."
        if let top = env.products.culprits.all.first {
            s += "\n\nYour shelf's top suspect ingredient is **\(top.name)**. Check whether anything you used recently contains it."
        }
        s += "\n\nIf the irritation is severe, spreading, or lasts more than a few days, see a dermatologist."
        return s
    }
}

/// Past conversations, newest first. Swipe to delete.
private struct AssistantHistoryView: View {
    let onOpen: (AssistantConversation) -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if env.assistant.conversations.isEmpty {
                    SKEmptyState(icon: "bubble.left.and.bubble.right",
                                 title: "No chats yet",
                                 message: "Your conversations with Ask Skintel are saved here, on this device.")
                        .padding(SKSpace.xl)
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(env.assistant.conversations) { c in
                            Button {
                                onOpen(c)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(2)
                                    Text(subtitle(c)).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(SKColor.cream)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { env.assistant.conversations[$0].id }
                            for id in ids { env.assistant.delete(id: id) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .skPageBackground()
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(SKFont.bodyMedium)
                }
            }
        }
        .tint(SKColor.primary)
    }

    private func subtitle(_ c: AssistantConversation) -> String {
        let questions = c.messages.filter { $0.role == .user }.count
        return "\(DateFormatting.relative(c.updatedAt)) · \(questions) \(questions == 1 ? "question" : "questions")"
    }
}

private enum AssistantPrompt: String, CaseIterable, Identifiable {
    case order, retinolVitaminC, irritated, patchTest

    var id: String { rawValue }

    var question: String {
        switch self {
        case .order: "What order should I use my products in?"
        case .retinolVitaminC: "Can I use retinol and vitamin C together?"
        case .irritated: "My skin feels irritated. What should I do tonight?"
        case .patchTest: "How do I patch test a new product?"
        }
    }

    var icon: String {
        switch self {
        case .order: "list.number"
        case .retinolVitaminC: "drop"
        case .irritated: "bandage"
        case .patchTest: "hand.raised"
        }
    }
}

private struct AssistantBubble: View {
    let message: AssistantMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(SKFont.body)
                    .foregroundStyle(SKColor.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(SKColor.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        case .assistant, .notice, .upsell:
            HStack(alignment: .top, spacing: SKSpace.md) {
                AssistantAvatar(size: 28)
                Text(Self.rich(message.text))
                    .font(SKFont.sans(16, relativeTo: .body))
                    .foregroundStyle(message.role == .assistant ? SKColor.ink : SKColor.muted)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    /// Inline markdown only (bold), keeping the answer's line breaks and numbering as written.
    static func rich(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    }
}

private struct AssistantAvatar: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(SKColor.cream)
            .frame(width: size, height: size)
            .background(SKColor.primary, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        HStack(spacing: SKSpace.md) {
            AssistantAvatar(size: 28)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(SKColor.muted)
                        .frame(width: 7, height: 7)
                        .opacity(on ? 1 : 0.3)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: on)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SKColor.cream, in: Capsule())
        }
        .onAppear { on = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Skintel is typing")
    }
}
