import SwiftUI
import SkintelCore

/// Design §12 on top of what `/api/lookup?mode=compare` actually returns: a plain-English
/// winner, and per product a score, one-liner, wins and concerns.
struct CompareView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    struct Slot: Identifiable, Hashable {
        let id = UUID()
        var productID: String?
        var name: String
        var inci: String
    }

    @State private var slots: [Slot] = [Slot(name: "", inci: ""), Slot(name: "", inci: "")]
    @State private var pickingIndex: Int?
    @State private var customIndex: Int?
    @State private var result: Loadable<CompareResult> = .idle

    private var ready: [Slot] { slots.filter { !INCI.parse($0.inci).isEmpty && !$0.name.isEmpty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compare").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                        Text("\(ready.count) of 3 picked").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                    }
                    .padding(.top, SKSpace.md)

                    if case .loaded(let r) = result, let w = r.winner, r.items.indices.contains(w.index) {
                        SKCard(tint: .good) {
                            HStack(alignment: .top, spacing: SKSpace.md) {
                                Image(systemName: "trophy").font(.system(size: 18, weight: .semibold)).foregroundStyle(SKColor.goodFg)
                                    .frame(width: 44, height: 44).background(SKColor.goodBg, in: Circle())
                                (Text("Winner: \(r.items[w.index].name). ").font(SKFont.sans(16, weight: .semibold)) + Text(w.reason ?? "").font(SKFont.body))
                                    .foregroundStyle(SKColor.ink)
                            }
                        }
                    }

                    slotGrid

                    if slots.count < 3 {
                        SKDashedButton(title: "+ Add a third product") { slots.append(Slot(name: "", inci: "")) }
                    }

                    if case .failed(let e) = result { SKInlineError(message: e.userMessage) }

                    SKButton(title: "Compare", systemImage: "sparkles", isLoading: result.isLoading) { Task { await compare() } }
                        .disabled(ready.count < 2)
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(SKColor.primary)
        .sheet(item: Binding(get: { pickingIndex.map { IndexBox(i: $0) } }, set: { if $0 == nil { pickingIndex = nil } })) { box in
            ShelfPickerSheet(exclude: Set(slots.compactMap(\.productID))) { id in
                if let p = env.products.product(id: id) {
                    slots[box.i] = Slot(productID: id, name: p.product.productName, inci: p.ingredients.map(\.inciRaw).joined(separator: ", "))
                    result = .idle
                }
            }
        }
        .sheet(item: Binding(get: { customIndex.map { IndexBox(i: $0) } }, set: { if $0 == nil { customIndex = nil } })) { box in
            CustomProductSheet(name: slots[box.i].name, inci: slots[box.i].productID == nil ? slots[box.i].inci : "") { name, inci in
                slots[box.i] = Slot(productID: nil, name: name, inci: inci)
                result = .idle
            }
        }
    }

    private struct IndexBox: Identifiable { let i: Int; var id: Int { i } }

    private var slotGrid: some View {
        let cols = [GridItem(.flexible(), spacing: SKSpace.md), GridItem(.flexible(), spacing: SKSpace.md)]
        return LazyVGrid(columns: cols, spacing: SKSpace.md) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { i, s in
                slotCard(i, s)
            }
        }
    }

    @ViewBuilder
    private func slotCard(_ i: Int, _ s: Slot) -> some View {
        let item = result.value?.items.indices.contains(i) == true ? result.value?.items[i] : nil
        let isWinner = result.value?.winner?.index == i
        VStack(alignment: .leading, spacing: SKSpace.md) {
            if s.name.isEmpty {
                VStack(spacing: SKSpace.sm) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(SKColor.primary)
                        .frame(width: 56, height: 56).background(SKColor.blush, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Product \(i + 1)").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKButton(title: "From shelf", kind: .secondary) { pickingIndex = i }
                    SKButton(title: "Paste INCI", kind: .ghost) { customIndex = i }
                }
                .frame(maxWidth: .infinity)
            } else {
                SKProductMark(name: s.name, size: 56)
                Text(s.name).font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if let item {
                    SKScoreRing(score: item.scoreInt, size: 96, lineWidth: 9, caption: item.verdict.label)
                        .frame(maxWidth: .infinity)
                    if let short = item.short, !short.isEmpty { Text(short).font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                    ForEach(item.keyWins?.values.prefix(3) ?? [], id: \.self) { Text("✓ \($0)").font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.goodFg) }
                    ForEach(item.keyConcerns?.values.prefix(3) ?? [], id: \.self) { Text("✗ \($0)").font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.badFg) }
                } else {
                    Text("\(INCI.parse(s.inci).count) ingredients").font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                }
                HStack {
                    Button("Change") { if s.productID != nil { pickingIndex = i } else { customIndex = i } }
                    Spacer()
                    if slots.count > 2 { Button("Remove") { slots.remove(at: i); result = .idle } }
                }
                .font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.primary)
            }
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(isWinner ? SKColor.goodFg : SKColor.line, lineWidth: isWinner ? 1.5 : 1))
        .skCardShadow()
    }

    private func compare() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.compare); return }
        result = .loading
        do {
            result = .loaded(try await env.api.compare(CompareRequest(products: ready.map { .init(name: $0.name, inci: String($0.inci.prefix(8000))) })))
            env.analytics.track(.compareRun)
            Haptics.success()
        } catch let e as APIError {
            if e.requiresPaywall { openPaywall(.compare); result = .idle } else { result = .failed(e) }
        } catch { result = .failed(.network(error.localizedDescription)) }
    }
}

struct CustomProductSheet: View {
    @State var name: String
    @State var inci: String
    let onDone: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("Product name")
                    SKTextField(placeholder: "e.g. Fenty Hydra Vizor", text: $name, autocapitalization: .words)
                    SKFieldLabel("Ingredients (INCI)")
                    SKTextEditor(placeholder: "Aqua, Glycerin, …", text: $inci, minHeight: 180, mono: true)
                    SKButton(title: "Use this product") { onDone(name.trimmingCharacters(in: .whitespaces), inci); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || INCI.parse(inci).isEmpty)
                }
                .skPagePadding().padding(.vertical, SKSpace.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPageBackground()
            .skNavigationTitle("Not on your shelf")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
    }
}
