import SwiftUI
import SkintelCore

/// Add / edit a product — the same fields as AddProduct.tsx / EditProduct.tsx. Category is
/// free text (as on the web) with quick picks. The INCI box shows the live parsed count so
/// a bad paste is obvious before saving.
struct ProductFormView: View {
    let mode: ProductFormMode
    /// Unsaved scan to attach once the product exists (so its score shows on the shelf).
    var attachScanID: String? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.dismiss) private var dismiss

    @State private var brand = ""
    @State private var name = ""
    @State private var category = ""
    @State private var outcome: Outcome = .unsure
    @State private var inci = ""
    @State private var notes = ""
    @State private var saving = false
    @State private var error: String?
    @State private var loaded = false
    @State private var savedID: String?
    @FocusState private var focus: Field?

    private enum Field { case brand, name, category, inci, notes }

    var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var parsed: [INCI.ParsedIngredient] { INCI.parse(inci) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !saving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                field("Product name", placeholder: "e.g. Foaming Facial Cleanser", text: $name, focus: .name, contentType: nil)
                field("Brand", placeholder: "e.g. CeraVe", text: $brand, focus: .brand, contentType: .organizationName)

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    SKFieldLabel("Category")
                    SKTextField(placeholder: "Cleanser, Serum, Sunscreen…", text: $category, autocapitalization: .words)
                        .focused($focus, equals: .category)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SKSpace.sm) {
                            ForEach(ProductCategory.allCases) { c in
                                SKSelectChip(title: c.rawValue, selected: category == c.rawValue) {
                                    category = category == c.rawValue ? "" : c.rawValue
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    SKFieldLabel("How did your skin react?")
                    HStack(spacing: SKSpace.sm) {
                        ForEach([Outcome.good, .unsure, .bad], id: \.self) { o in
                            Button {
                                outcome = o; Haptics.selection()
                            } label: {
                                VStack(spacing: 6) {
                                    Text(o == .good ? "✨" : o == .unsure ? "🤔" : "🌋").font(.system(size: 22))
                                    Text(o.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                                }
                                .foregroundStyle(outcome == o ? o.tone.fg : SKColor.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 78)
                                .background(outcome == o ? o.tone.bg : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                                    .stroke(outcome == o ? o.tone.fg : SKColor.line, lineWidth: outcome == o ? 1.5 : 1))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(outcome == o ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    HStack {
                        SKFieldLabel("Ingredients (INCI)")
                        Spacer()
                        Text(parsed.isEmpty ? "paste from the packaging" : "\(parsed.count) parsed")
                            .font(SKFont.dataSmall).foregroundStyle(parsed.isEmpty ? SKColor.muted : SKColor.goodFg)
                    }
                    SKTextEditor(placeholder: "Aqua, Glycerin, Niacinamide, …", text: $inci, minHeight: 140, mono: true)
                        .focused($focus, equals: .inci)
                    if !parsed.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(parsed.prefix(12), id: \.normalized) { i in SKChip(i.raw) }
                            if parsed.count > 12 { SKChip("+\(parsed.count - 12)") }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    SKFieldLabel("Notes")
                    SKTextEditor(placeholder: "Stung around the nose, fine on cheeks…", text: $notes, minHeight: 90)
                        .focused($focus, equals: .notes)
                }

                if let error { SKInlineError(message: error) }

                SKButton(title: isEdit ? "Save changes" : "Save to shelf", isLoading: saving) { Task { await save() } }
                    .disabled(!canSave)
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.lg)
            .padding(.bottom, SKSpace.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .skPageBackground()
        .skNavigationTitle(isEdit ? "Edit product" : "Add product")
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack { Spacer(); Button("Done") { focus = nil }.font(SKFont.bodyMedium) }
            }
        }
        .onAppear(perform: prefill)
        .navigationDestination(item: $savedID) { id in ProductDetailView(productID: id) }
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>, focus f: Field, contentType: UITextContentType?) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            SKFieldLabel(label)
            SKTextField(placeholder: placeholder, text: text, contentType: contentType, autocapitalization: .words, submitLabel: .next) {
                focus = f == .name ? .brand : .category
            }
            .focused($focus, equals: f)
        }
    }

    private func prefill() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .add(let c):
            if let c {
                brand = c.brand ?? ""
                name = c.productName ?? ""
                inci = c.inci
            }
        case .edit(let id):
            guard let p = env.products.product(id: id) else { return }
            brand = p.product.brand ?? ""
            name = p.product.productName
            category = p.product.category ?? ""
            outcome = p.product.outcome
            notes = p.product.notes ?? ""
            inci = p.ingredients.map(\.inciRaw).joined(separator: ", ")
        }
    }

    private func save() async {
        guard let uid = env.session.user?.id else { error = APIError.unauthenticated.userMessage; return }
        saving = true; error = nil
        defer { saving = false }
        do {
            switch mode {
            case .add:
                if !env.subscription.entitlement.canAddProduct(currentCount: env.products.products.count) {
                    openPaywall(.productLimit); return
                }
                let created = try await env.products.add(userID: uid, brand: brand, name: name.trimmingCharacters(in: .whitespaces),
                                                         category: category, outcome: outcome, notes: notes, ingredients: parsed)
                if let attachScanID { env.scans.attach(scanID: attachScanID, to: created.id) }
                env.analytics.track(.productSaved)
                Haptics.success()
                savedID = created.id
            case .edit(let id):
                let patch = PostgRESTClient.ProductPatch(
                    brand: .set(brand.isEmpty ? nil : brand),
                    productName: .set(name.trimmingCharacters(in: .whitespaces)),
                    category: .set(category.isEmpty ? nil : category),
                    outcome: .set(outcome),
                    notes: .set(notes.isEmpty ? nil : notes)
                )
                let original = env.products.product(id: id)?.ingredients.map(\.inciRaw).joined(separator: ", ") ?? ""
                try await env.products.update(id: id, userID: uid, patch: patch, ingredients: original == inci ? nil : parsed)
                Haptics.success()
                dismiss()
            }
        } catch let e as APIError where e == .freePlanLimit {
            openPaywall(.productLimit)
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
            Haptics.error()
        }
    }
}
