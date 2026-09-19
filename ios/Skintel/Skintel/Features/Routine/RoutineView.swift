import SwiftUI
import SkintelCore

/// Design §13. Ordered steps per slot, tap to tick off (strike-through, 60% opacity),
/// drag to reorder, conflicts from `/api/analyze-routine`.
struct RoutineView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    @State private var slot: RoutineStore.Slot = RoutineStore.currentSlot()
    @State private var analysis: Loadable<RoutineAnalysis> = .idle
    @State private var showPicker = false
    @State private var showTemplates = false
    @State private var editMode: EditMode = .inactive

    private var ids: [String] { env.routine.ids(slot) }

    var body: some View {
        List {
            Section {
                header.listRowBackground(Color.clear).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            }
            if ids.isEmpty {
                Section {
                    emptyState.listRowBackground(Color.clear).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                        stepRow(index: i, id: id)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: SKSpace.xl, bottom: 4, trailing: SKSpace.xl))
                            .listRowSeparator(.hidden)
                    }
                    .onMove { env.routine.move(from: $0, to: $1, in: slot); Haptics.selection() }
                    .onDelete { idx in idx.map { ids[$0] }.forEach { env.routine.remove($0, from: slot) } }
                }
                Section {
                    conflicts.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: SKSpace.xl, bottom: 4, trailing: SKSpace.xl)).listRowSeparator(.hidden)
                    SKDashedButton(title: "+ Add step from shelf") { showPicker = true }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: SKSpace.xl, bottom: 40, trailing: SKSpace.xl)).listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton().padding(.top, 2) }
        .sheet(isPresented: $showPicker) { ShelfPickerSheet(exclude: Set(ids)) { env.routine.add($0, to: slot); Haptics.success() } }
        .sheet(isPresented: $showTemplates) { templatesSheet }
        .onChange(of: slot) { _, _ in analysis = .idle }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(alignment: .center) {
                Text("Routine").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, 44)
                Spacer()
                SKSegmented(options: [(RoutineStore.Slot.am, "AM"), (.pm, "PM")], selection: $slot).frame(width: 150)
            }
            HStack {
                Text(ids.isEmpty ? "No steps yet" : "\(ids.count) step\(ids.count == 1 ? "" : "s") · ~\(max(1, ids.count)) minute\(ids.count == 1 ? "" : "s")")
                    .font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                Spacer()
                if ids.count > 1 {
                    Button(editMode == .active ? "Done" : "Reorder") {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                    .font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.primary)
                }
            }
        }
        .skPagePadding()
        .padding(.top, SKSpace.md)
        .padding(.bottom, SKSpace.sm)
    }

    private var emptyState: some View {
        VStack(spacing: SKSpace.md) {
            SKEmptyState(icon: "list.number", title: "Build your \(slot.rawValue) routine",
                         message: env.products.products.isEmpty
                         ? "Add products to your shelf first, then order them here."
                         : "Pick steps from your shelf, or start from a template and adjust.")
            if !env.products.products.isEmpty {
                VStack(spacing: SKSpace.sm) {
                    SKButton(title: "Add step from shelf") { showPicker = true }
                    SKButton(title: "Start from a template", kind: .secondary) { showTemplates = true }
                }
                .skPagePadding()
            }
        }
        .padding(.bottom, SKSpace.xxl)
    }

    private func stepRow(index: Int, id: String) -> some View {
        let p = env.products.product(id: id)
        let done = env.routine.isDone(id)
        let score = env.scans.score(for: id)
        return Button {
            env.routine.toggleDone(id); Haptics.selection()
        } label: {
            HStack(spacing: SKSpace.md) {
                ZStack {
                    Circle().fill(done ? SKColor.goodBg : SKColor.neutralChip).frame(width: 36, height: 36)
                    if done { Text("✓").font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.goodFg) }
                    else { Text("\(index + 1)").font(SKFont.mono(13)).foregroundStyle(SKColor.muted) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(p?.product.productName ?? "Removed product")
                        .font(SKFont.cardTitle).foregroundStyle(SKColor.ink).strikethrough(done, color: SKColor.muted).lineLimit(1)
                    Text([p?.product.category, p?.product.brand].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                }
                Spacer(minLength: SKSpace.sm)
                if let score { SKScoreBadge(score: score) }
                else if let o = p?.product.outcome { SKChip(o.label, tone: o.tone) }
            }
            .padding(SKSpace.md)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
            .opacity(done ? 0.6 : 1)
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("\(p?.product.productName ?? "step") \(done ? "done" : "not done")")
        .accessibilityHint("Double-tap to mark \(done ? "not done" : "done")")
    }

    // MARK: Conflicts

    @ViewBuilder
    private var conflicts: some View {
        switch analysis {
        case .idle:
            SKButton(title: "Check for conflicts", kind: .secondary, systemImage: "sparkles") { Task { await analyze() } }
                .disabled(env.routine.ids(.am).isEmpty && env.routine.ids(.pm).isEmpty)
        case .loading:
            SKCard { HStack(spacing: SKSpace.md) { ProgressView().tint(SKColor.primary); Text("Checking both routines…").font(SKFont.secondary).foregroundStyle(SKColor.muted) } }
        case .failed(let e):
            SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: e.userMessage); SKButton(title: "Try again", kind: .secondary) { Task { await analyze() } } } }
        case .loaded(let a):
            VStack(spacing: SKSpace.md) {
                if a.conflicts.isEmpty {
                    SKCard(tint: .good) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No conflicts found").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            if let v = (slot == .am ? a.amVerdict : a.pmVerdict), !v.isEmpty { Text(v).font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                        }
                    }
                }
                ForEach(a.conflicts) { c in
                    SKCard(tint: c.isHigh ? .bad : .caution) {
                        HStack(alignment: .top, spacing: SKSpace.md) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 18, weight: .semibold)).foregroundStyle(c.isHigh ? SKColor.badFg : SKColor.cautionFg)
                            VStack(alignment: .leading, spacing: 6) {
                                (Text("Conflict: ").font(SKFont.sans(16, weight: .semibold)) + Text(c.issue).font(SKFont.body))
                                    .foregroundStyle(SKColor.ink)
                                if let ps = c.products?.values, !ps.isEmpty { Text(ps.joined(separator: " + ")).font(SKFont.dataSmall).foregroundStyle(SKColor.muted) }
                                if let fix = c.fix, !fix.isEmpty {
                                    Text(fix).font(SKFont.sans(15, weight: .semibold)).foregroundStyle(c.isHigh ? SKColor.badFg : SKColor.cautionFg)
                                }
                            }
                        }
                    }
                }
                if let s = a.suggestions?.values, !s.isEmpty {
                    SKCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suggestions").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            ForEach(s, id: \.self) { Text("• \($0)").font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        }
                    }
                }
            }
        }
    }

    private func analyze() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.routine); return }
        analysis = .loading
        do {
            analysis = .loaded(try await env.api.analyzeRoutine(amProductIDs: env.routine.ids(.am), pmProductIDs: env.routine.ids(.pm)))
            env.analytics.track(.routineAnalyzed)
        } catch let e as APIError {
            if e.requiresPaywall { openPaywall(.routine); analysis = .idle } else { analysis = .failed(e) }
        } catch { analysis = .failed(.network(error.localizedDescription)) }
    }

    // MARK: Templates

    private var templatesSheet: some View {
        RoutineTemplatesSheet(products: env.products.products) { am, pm in
            env.routine.set(am, for: .am)
            env.routine.set(pm, for: .pm)
            Haptics.success()
            showTemplates = false
        }
    }
}

/// A compact category preview. The illustrations describe the template's steps;
/// counts are computed from the actual shelf, and only those matched products apply.
private struct RoutineTemplatesSheet: View {
    let products: [ProductWithIngredients]
    let onSelect: ([String], [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var previewSlot: RoutineStore.Slot = .am

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        Text("A little structure.\nYour own products.")
                            .font(SKFont.editorial(28, relativeTo: .title))
                            .foregroundStyle(SKColor.ink)
                        Text("Pick a starting point. Edit any step later.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                    SKSegmented(options: [(RoutineStore.Slot.am, "Morning"), (.pm, "Evening")], selection: $previewSlot)
                        .accessibilityLabel("Preview time of day")

                    ForEach(RoutineTemplate.all) { template in
                        templateCard(template)
                    }
                    Text("Applies both routines using matches from your shelf. Check each product suits your skin.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
                .skPagePadding().padding(.vertical, SKSpace.lg)
            }
            .skPageBackground()
            .skNavigationTitle("Templates")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
        .transaction { transaction in
            if reduceMotion { transaction.disablesAnimations = true }
        }
    }

    private func templateCard(_ template: RoutineTemplate) -> some View {
        let am = template.fill(template.am, from: products)
        let pm = template.fill(template.pm, from: products)
        let tags = previewSlot == .am ? template.am : template.pm
        let canApply = !am.isEmpty || !pm.isEmpty
        let stepSummary = tags.map { previewStep($0).label }.joined(separator: ", ")

        return Button {
            onSelect(am, pm)
        } label: {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(SKFont.sans(18, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(SKColor.ink)
                    Text(template.blurb).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                templateSteps(tags)
                    .id(previewSlot)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: previewSlot)
                HStack(alignment: .firstTextBaseline, spacing: SKSpace.sm) {
                    Text(canApply ? "\(am.count) AM · \(pm.count) PM from your shelf" : "Add matching products to get started")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if canApply {
                        Text("Use template")
                            .font(SKFont.sans(12, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(SKColor.primary)
                    }
                }
            }
            .padding(SKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
        }
        .buttonStyle(SKPressStyle())
        .disabled(!canApply)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name). \(template.blurb) \(previewSlot == .am ? "Morning" : "Evening") preview: \(stepSummary). \(am.count) morning and \(pm.count) evening steps available from your shelf.")
        .accessibilityHint(canApply ? "Replaces your morning and evening routines with matching products." : "Add matching products to your shelf first.")
    }

    private func templateSteps(_ tags: [String]) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SKSpace.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 4))

        return layout {
            ForEach(tags, id: \.self) { tag in
                let step = previewStep(tag)
                let stepLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(HStackLayout(alignment: .center, spacing: SKSpace.sm))
                    : AnyLayout(VStackLayout(alignment: .center, spacing: 6))
                stepLayout {
                    Image(systemName: step.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(SKColor.primary)
                        .frame(width: 36, height: 36)
                        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(step.label)
                        .font(SKFont.sans(11, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(SKColor.ink)
                        .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            }
        }
        .accessibilityHidden(true)
    }

    private func previewStep(_ category: String) -> (label: String, symbol: String) {
        switch category {
        case "cleanser": ("Cleanse", "drop")
        case "toner": ("Tone", "drop.circle")
        case "serum": ("Serum", "eyedropper")
        case "exfoliant": ("Exfoliate", "sparkles")
        case "moisturizer": ("Moisturize", "drop.fill")
        case "sunscreen": ("SPF", "sun.max")
        default: (category.capitalized, "circle")
        }
    }
}

/// Pick a product from the shelf (routine steps, compare slots).
struct ShelfPickerSheet: View {
    var exclude: Set<String> = []
    let onPick: (String) -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SKSpace.sm) {
                    SKTextField(placeholder: "Search your shelf", text: $query, autocapitalization: .never)
                    let items = env.products.products.filter { !exclude.contains($0.id) && (query.isEmpty || $0.product.productName.localizedCaseInsensitiveContains(query) || ($0.product.brand ?? "").localizedCaseInsensitiveContains(query)) }
                    if items.isEmpty {
                        SKEmptyState(icon: "tray", title: "Nothing to add", message: exclude.isEmpty ? "Your shelf is empty." : "Everything on your shelf is already here.")
                    }
                    ForEach(items) { p in
                        Button { onPick(p.id); dismiss() } label: { ProductRow(product: p, score: env.scans.score(for: p.id)) }
                            .buttonStyle(SKPressStyle())
                    }
                }
                .skPagePadding().padding(.vertical, SKSpace.lg)
            }
            .skPageBackground()
            .skNavigationTitle("From your shelf")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
        .presentationDetents([.medium, .large])
    }
}
