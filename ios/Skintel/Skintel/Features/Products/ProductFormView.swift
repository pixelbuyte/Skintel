import SwiftUI
import UIKit
import SkintelCore

/// Add / edit a product ("Type it in"). Name first with the keyboard up for a new product,
/// category as chips, the reaction as three tinted symbols, and the INCI box with a Paste
/// button and a live count — the list is what verdicts and Triggers run on, so the form says
/// so, and a bad paste is obvious before saving.
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
    /// A category saved on the web that isn't one of the chips, kept as a chip so editing
    /// doesn't silently drop it.
    @State private var customCategory: String?
    @State private var outcome: Outcome = .unsure
    @State private var inci = ""
    @State private var notes = ""
    @State private var saving = false
    @State private var error: String?
    @State private var loaded = false
    @State private var savedID: String?
    @FocusState private var focus: Field?

    private enum Field { case name, brand, inci, notes }

    var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var parsed: [INCI.ParsedIngredient] { INCI.parse(inci) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !saving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                textField("Product name", placeholder: "e.g. Foaming Facial Cleanser", text: $name, field: .name,
                          contentType: nil, submit: .next) { focus = .brand }
                textField("Brand", placeholder: "e.g. CeraVe", text: $brand, field: .brand,
                          contentType: .organizationName, submit: .done) { focus = nil }
                categoryPicker
                reactionPicker
                ingredientsField

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
        .task { await focusNameIfNew() }
        .navigationDestination(item: $savedID) { id in ProductDetailView(productID: id) }
    }

    // MARK: Fields

    private func textField(_ label: String, placeholder: String, text: Binding<String>, field: Field,
                           contentType: UITextContentType?, submit: SubmitLabel,
                           next: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            SKFieldLabel(label)
            SKTextField(placeholder: placeholder, text: text, contentType: contentType, autocapitalization: .words,
                        submitLabel: submit, onSubmit: next)
                .focused($focus, equals: field)
        }
    }

    private var categoryOptions: [String] {
        (customCategory.map { [$0] } ?? []) + ProductCategory.allCases.map(\.rawValue)
    }

    /// Chips only. The label names the pick, since it can be scrolled out of view.
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            SKFieldLabel(category.isEmpty ? "Category" : "Category · \(category)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SKSpace.sm) {
                    ForEach(categoryOptions, id: \.self) { c in
                        SKSelectChip(title: c, selected: category == c) {
                            category = category == c ? "" : c
                            Haptics.selection()
                        }
                    }
                }
                .padding(.horizontal, SKSpace.xl)
            }
            .padding(.horizontal, -SKSpace.xl)
        }
    }

    private var reactionPicker: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            SKFieldLabel("How did your skin react?")
            HStack(spacing: SKSpace.sm) {
                ForEach([Outcome.good, .unsure, .bad], id: \.self) { o in
                    reactionButton(o)
                }
            }
        }
    }

    private func reactionButton(_ o: Outcome) -> some View {
        let on = outcome == o
        let look = ReactionLook(o)
        return Button {
            outcome = o
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: look.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(look.tint)
                    .accessibilityHidden(true)
                Text(o.label)
                    .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(on ? SKColor.ink : SKColor.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .padding(.vertical, SKSpace.xs)
            .background(on ? look.fill : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(on ? look.tint : SKColor.line, lineWidth: on ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel(o.label)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var ingredientsField: some View {
        let n = parsed.count
        return VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack {
                SKFieldLabel("Ingredients (INCI)")
                Spacer()
                ClipboardPasteButton { text in inci = text }
            }
            SKTextEditor(placeholder: "Aqua, Glycerin, Niacinamide, …", text: $inci, minHeight: 140, mono: true)
                .focused($focus, equals: .inci)
            HStack(spacing: 6) {
                if n > 0 {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12, weight: .semibold))
                }
                Text(n == 0 ? "Paste the list exactly as printed, commas between ingredients."
                            : "\(n) ingredient\(n == 1 ? "" : "s") recognised")
            }
            .font(SKFont.dataSmall)
            .foregroundStyle(n == 0 ? SKColor.muted : SKColor.goodFg)
            .accessibilityElement(children: .combine)
            if n > 0 {
                FlowLayout(spacing: 6) {
                    ForEach(parsed.prefix(12), id: \.normalized) { i in SKChip(i.raw) }
                    if n > 12 { SKChip("+\(n - 12)") }
                }
            }
            Label {
                Text("The ingredient list is what makes verdicts and Triggers work. Without it, Skintel can't check this product or line it up against the ones that broke you out.")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(SKFont.caption)
            .foregroundStyle(SKColor.muted)
            .padding(.top, SKSpace.xs)
        }
    }

    // MARK: Load / save

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
            let saved = p.product.category ?? ""
            if !saved.isEmpty && !ProductCategory.allCases.contains(where: { $0.rawValue == saved }) {
                customCategory = saved
            }
            category = saved
            outcome = p.product.outcome
            notes = p.product.notes ?? ""
            inci = p.ingredients.map(\.inciRaw).joined(separator: ", ")
        }
    }

    /// A new product starts at the name with the keyboard up, once the push or sheet settles.
    private func focusNameIfNew() async {
        guard !isEdit, name.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, focus == nil, name.isEmpty else { return }
        focus = .name
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

/// The reaction picker's symbols: sage sparkles, a neutral question mark, a red flame.
/// Deliberately no emoji and no amber for "Unsure".
private struct ReactionLook {
    let symbol: String
    let tint: Color
    let fill: Color

    init(_ outcome: Outcome) {
        switch outcome {
        case .good:
            symbol = "sparkles"; tint = SKColor.goodFg; fill = SKColor.goodBg
        case .unsure:
            symbol = "questionmark"; tint = SKColor.muted; fill = SKColor.neutralChip
        case .bad:
            symbol = "flame"; tint = SKColor.badFg; fill = SKColor.badBg
        }
    }
}
