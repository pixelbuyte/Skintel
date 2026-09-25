import SwiftUI
import SkintelCore
import SkinstelMascot

/// The shelf: every product, newest first, with the free-tier cap made visible.
struct ProductsListView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var pendingDelete: ProductWithIngredients?
    @State private var deleteError: String?
    @State private var showCompare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                capBanner
                switch env.products.state {
                case .idle, .loading:
                    ForEach(0..<5, id: \.self) { _ in SKSkeleton(height: 76) }
                case .failed(let e):
                    SKErrorState(error: e) { Task { await env.products.load() } }
                case .loaded(let products):
                    if products.isEmpty {
                        if samplesHidden {
                            SKEmptyState(icon: "tray", title: "Nothing on the shelf",
                                         message: "Add what you use and how your skin reacted. Skintel needs two “broke out” products to start finding patterns.",
                                         mascot: .serum,
                                         actionTitle: "Add your first product") { addTapped() }
                        } else {
                            SampleShelf(onAdd: { addTapped() }) { withAnimation(SKAnimation.ios(0.3)) { samplesHidden = true } }
                        }
                    } else {
                        ForEach(products) { p in
                            NavigationLink(value: AppDestination.productDetail(id: p.id)) {
                                ProductRow(product: p, score: env.scans.score(for: p.id))
                            }
                            .buttonStyle(SKPressStyle())
                            .contextMenu {
                                NavigationLink(value: AppDestination.productForm(.edit(productID: p.id))) { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.md)
            .padding(.bottom, SKSpace.xxl)
        }
        .refreshable { await env.products.load() }
        .skPageBackground()
        .skHint(.shelf, when: !env.products.products.isEmpty)
        .skNavigationTitle("Shelf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if env.subscription.entitlement.isPro { showCompare = true } else { openPaywall(.compare) }
                } label: { Image(systemName: "arrow.left.arrow.right").font(.system(size: 16, weight: .semibold)) }
                    .accessibilityLabel("Compare products")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { addTapped() } label: { Image(systemName: "plus").font(.system(size: 17, weight: .semibold)) }
                    .accessibilityLabel("Add product")
            }
        }
        .sheet(isPresented: $showCompare) { CompareView().skProGates() }
        .navigationDestination(for: AppDestination.self) { d in
            switch d {
            case .productDetail(let id): ProductDetailView(productID: id)
            case .productForm(let mode): ProductFormView(mode: mode)
            default: EmptyView()
            }
        }
        .confirmationDialog("Delete \(pendingDelete?.product.productName ?? "product")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let p = pendingDelete else { return }
                Task {
                    do {
                        try await env.products.delete(id: p.id)
                        env.scans.remove(productID: p.id)
                        // Like deleting from the product page: a stale routine step would keep
                        // that routine from ever counting as done.
                        env.routine.remove(p.id, from: .am)
                        env.routine.remove(p.id, from: .pm)
                        Haptics.success()
                    }
                    catch { deleteError = (error as? APIError)?.userMessage ?? error.localizedDescription }
                }
            }
        } message: {
            Text("Its ingredients stop counting toward your Triggers too. This can't be undone.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(deleteError ?? "") }
        .environment(\.addProductAction, AddProductAction(handler: addTapped))
    }

    @State private var presentAdd = false
    /// "Hide samples" on the empty shelf, remembered on this device.
    @AppStorage("shelf.samplesHidden") private var samplesHidden = false

    private func addTapped() {
        let ent = env.subscription.entitlement
        if !ent.canAddProduct(currentCount: env.products.products.count) {
            openPaywall(.productLimit)
        } else {
            presentAdd = true
        }
    }

    @ViewBuilder
    private var capBanner: some View {
        let ent = env.subscription.entitlement
        if let limit = ent.productLimit, env.products.isLoaded {
            let n = env.products.products.count
            Button { openPaywall(.general) } label: {
                HStack(spacing: SKSpace.md) {
                    SKProgressBar(fraction: Double(n) / Double(limit), tone: n >= limit ? .bad : .neutral, height: 6)
                        .frame(width: 80)
                    Text(n >= limit ? "Free shelf is full · \(limit) of \(limit)" : "\(n) of \(limit) free slots used")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    Spacer()
                    Text("Get Skintel+ ›").font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.primary)
                }
                .padding(SKSpace.md)
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous).stroke(SKColor.line))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $presentAdd) { AddProductHub().skProGates() }
        } else {
            Color.clear.frame(height: 0)
                .sheet(isPresented: $presentAdd) { AddProductHub().skProGates() }
        }
    }
}

/// What a shelf looks like with a few products in it, shown only while the real shelf is
/// empty. The samples are view-only: never written to the server or to `ProductStore`, not
/// tappable, and clearly marked. The one action is adding your own.
private struct SampleShelf: View {
    let onAdd: () -> Void
    let onHide: () -> Void

    private struct Sample: Identifiable, Sendable {
        let name: String
        let kind: String
        let art: String
        let outcome: Outcome
        var id: String { name }
    }

    private static let samples: [Sample] = [
        Sample(name: "Gentle foaming cleanser", kind: "Cleanser", art: ProductArt.pump, outcome: .good),
        Sample(name: "Niacinamide 10% serum", kind: "Serum", art: ProductArt.dropper, outcome: .bad),
        Sample(name: "Mineral sunscreen SPF 50", kind: "Sunscreen", art: ProductArt.tube, outcome: .good),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack(alignment: .center, spacing: SKSpace.md) {
                SKMascot(action: .serum, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your shelf starts here").font(SKFont.section).foregroundStyle(SKColor.ink)
                    Text("Add what you use and how your skin reacted. With a few products in, it looks like this:")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, SKSpace.sm)

            HStack(alignment: .center) {
                Text("Sample shelf").skLabelStyle()
                Spacer()
                Button("Hide samples", action: onHide)
                    .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.muted)
                    .frame(minHeight: 44)
            }

            VStack(spacing: SKSpace.sm) {
                ForEach(Self.samples) { row($0) }
            }
            .allowsHitTesting(false)

            Text("Skintel needs two “broke out” products to start finding patterns.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)

            SKButton(title: "Add your own", systemImage: "plus", action: onAdd)
                .padding(.top, SKSpace.xs)
        }
    }

    private func row(_ sample: Sample) -> some View {
        HStack(spacing: SKSpace.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.neutralChip)
                Image(sample.art)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 5)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(sample.name).font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text("Sample")
                        .font(SKFont.mono(10, bold: true, relativeTo: .caption2))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(SKColor.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(SKColor.muted.opacity(0.5), lineWidth: 1))
                    Text(sample.kind).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                }
            }
            Spacer(minLength: SKSpace.sm)
            SKChip(sample.outcome.label, tone: sample.outcome.tone)
        }
        .padding(SKSpace.md)
        .background(SKColor.cream.opacity(0.55), in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(SKColor.muted.opacity(0.35))
        }
        .saturation(0.35)
        .opacity(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample, not on your shelf: \(sample.name), \(sample.kind.lowercased()), marked \(sample.outcome.label)")
    }
}

struct AddProductAction {
    let handler: @MainActor () -> Void
    @MainActor func callAsFunction() { handler() }
}

private struct AddProductKey: EnvironmentKey {
    static let defaultValue = AddProductAction { }
}

extension EnvironmentValues {
    var addProductAction: AddProductAction {
        get { self[AddProductKey.self] }
        set { self[AddProductKey.self] = newValue }
    }
}
