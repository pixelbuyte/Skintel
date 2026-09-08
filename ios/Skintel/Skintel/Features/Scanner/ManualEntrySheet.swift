import SwiftUI
import SkintelCore

/// "Type it": the web scanner's other tabs — barcode number, pasted INCI, product link,
/// and catalogue search — in one sheet.
struct ManualEntrySheet: View {
    @Bindable var model: ScanFlowModel
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Hashable { case barcode, paste, link, search }
    @State private var mode: Mode = .paste
    @State private var barcode = ""
    @State private var name = ""
    @State private var brand = ""
    @State private var inci = ""
    @State private var link = ""
    @State private var query = ""
    @State private var results: Loadable<[ProductSearchResult]> = .idle
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    SKSegmented(options: [(Mode.paste, "Paste"), (.barcode, "Barcode"), (.link, "Link"), (.search, "Search")], selection: $mode)
                    switch mode {
                    case .paste: paste
                    case .barcode: barcodeEntry
                    case .link: linkEntry
                    case .search: search
                    }
                }
                .skPagePadding()
                .padding(.vertical, SKSpace.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPageBackground()
            .skNavigationTitle("Add a product")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) }
            }
        }
        .tint(SKColor.primary)
        .presentationDetents([.large])
    }

    private var paste: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKTextField(placeholder: "Product name (optional)", text: $name, autocapitalization: .words)
            SKTextField(placeholder: "Brand (optional)", text: $brand, autocapitalization: .words)
            SKFieldLabel("Ingredients (INCI)")
            SKTextEditor(placeholder: "Aqua, Glycerin, Niacinamide, …", text: $inci, minHeight: 160, mono: true)
            let n = INCI.parse(inci).count
            Text(n == 0 ? "Paste the list exactly as printed — commas between ingredients." : "\(n) ingredients parsed")
                .font(SKFont.dataSmall).foregroundStyle(n == 0 ? SKColor.muted : SKColor.goodFg)
            SKButton(title: "Analyze") {
                dismiss()
                Task { await model.usePasted(brand: brand, name: name, inci: inci) }
            }
            .disabled(n == 0)
        }
    }

    private var barcodeEntry: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKFieldLabel("Barcode number")
            SKTextField(placeholder: "8–13 digits under the bars", text: $barcode, keyboard: .numberPad, submitLabel: .search)
            SKButton(title: "Look it up") {
                dismiss()
                Task { await model.lookup(upc: barcode.filter(\.isNumber)) }
            }
            .disabled(!(8...13).contains(barcode.filter(\.isNumber).count))
        }
    }

    private var linkEntry: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKFieldLabel("Product page")
            SKTextField(placeholder: "https://…", text: $link, keyboard: .URL, contentType: .URL, autocapitalization: .never, submitLabel: .go)
            Text("Works with most retailer and brand pages. Some sites block bots; if that happens, paste the list instead.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
            SKButton(title: "Import ingredients") {
                dismiss()
                Task { await model.importURL(link.trimmingCharacters(in: .whitespaces)) }
            }
            .disabled(URL(string: link.trimmingCharacters(in: .whitespaces))?.host == nil)
        }
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKTextField(placeholder: "Search Open Beauty Facts", text: $query, autocapitalization: .never, submitLabel: .search) { runSearch() }
                .onChange(of: query) { _, _ in scheduleSearch() }
            switch results {
            case .idle:
                Text("Type a brand or product name. Results include the ingredient list when the catalogue has it.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
            case .loading:
                ForEach(0..<3, id: \.self) { _ in SKSkeleton(height: 64) }
            case .failed(let e):
                SKErrorState(error: e) { runSearch() }
            case .loaded(let items):
                if items.isEmpty {
                    Text("No matches. Try fewer words, or paste the list.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                ForEach(items) { r in
                    Button {
                        dismiss()
                        Task { await model.useSearchResult(r) }
                    } label: {
                        SKCard(padding: SKSpace.md) {
                            HStack(spacing: SKSpace.md) {
                                SKProductMark(name: r.productName ?? r.brand ?? "?", size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.productName ?? "Unnamed").font(SKFont.bodyMedium).foregroundStyle(SKColor.ink).lineLimit(1)
                                    Text([r.brand, (r.ingredients?.isEmpty == false) ? "has INCI" : "no INCI listed"].compactMap { $0 }.joined(separator: " · "))
                                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(SKColor.muted)
                            }
                        }
                    }
                    .buttonStyle(SKPressStyle())
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = .idle; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { return }
            runSearch()
        }
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        results = .loading
        Task {
            do { results = .loaded(try await env.api.searchProducts(q)) }
            catch let e as APIError { results = .failed(e) }
            catch { results = .failed(.network(error.localizedDescription)) }
        }
    }
}
