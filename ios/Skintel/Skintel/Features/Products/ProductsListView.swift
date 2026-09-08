import SwiftUI
import SkintelCore

/// The shelf: every product, newest first, with the free-tier cap made visible.
struct ProductsListView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var pendingDelete: ProductWithIngredients?
    @State private var deleteError: String?

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
                        SKEmptyState(icon: "tray", title: "Nothing on the shelf",
                                     message: "Add what you use and how your skin reacted. Skintel needs two “broke out” products to start finding patterns.")
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
        .skNavigationTitle("Shelf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addTapped() } label: { Image(systemName: "plus").font(.system(size: 17, weight: .semibold)) }
                    .accessibilityLabel("Add product")
            }
        }
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
                    do { try await env.products.delete(id: p.id); env.scans.remove(productID: p.id); Haptics.success() }
                    catch { deleteError = (error as? APIError)?.userMessage ?? error.localizedDescription }
                }
            }
        } message: {
            Text("Its ingredients leave your culprit analysis too. This can't be undone.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(deleteError ?? "") }
        .environment(\.addProductAction, AddProductAction(handler: addTapped))
    }

    @State private var presentAdd = false

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
            Button { openPaywall(.productLimit) } label: {
                HStack(spacing: SKSpace.md) {
                    SKProgressBar(fraction: Double(n) / Double(limit), tone: n >= limit ? .bad : .neutral, height: 6)
                        .frame(width: 80)
                    Text(n >= limit ? "Free shelf is full · \(limit) of \(limit)" : "\(n) of \(limit) free slots used")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    Spacer()
                    Text("Go Pro ›").font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.primary)
                }
                .padding(SKSpace.md)
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous).stroke(SKColor.line))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $presentAdd) {
                NavigationStack { ProductFormView(mode: .add(prefill: nil)) }
            }
        } else {
            Color.clear.frame(height: 0)
                .sheet(isPresented: $presentAdd) {
                    NavigationStack { ProductFormView(mode: .add(prefill: nil)) }
                }
        }
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
