import SwiftUI
import UIKit
import SkintelCore

/// "Add a product": where every add path starts (the + menu, the shelf's +, and each "Add
/// your first product"). The fast paths lead — barcode, label photo, product link — and typing
/// it in is the fallback. Scan, photo and link run through Skintel's AI and are Skintel+ on the
/// server (402), so free accounts see them badged and a tap opens the same scanner paywall the
/// + menu uses; typing a product in stays free within the free shelf limit.
struct AddProductHub: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ScanFlowModel?

    var body: some View {
        Group {
            if let model {
                AddProductFlow(model: model)
            } else {
                SKColor.bg.ignoresSafeArea()
            }
        }
        .onAppear { if model == nil { model = ScanFlowModel(env: env) } }
    }
}

/// Pages pushed inside the hub that aren't shared `AppDestination`s.
enum AddProductRoute: Hashable {
    case link
    case photo
}

/// The hub's navigation: its own stack, scan model and paywall (a second sheet can't come
/// from the view that presented this one), and the one in-flight import so a page can cancel
/// it. Label photos and links end on the same verdict screen the barcode scanner pushes.
private struct AddProductFlow: View {
    let model: ScanFlowModel

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    /// Depth of the pushed verdict; popping back past it re-arms the flow.
    @State private var verdictDepth: Int?
    @State private var work: Task<Void, Never>?
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var paywall: PaywallReason?

    private enum Choice { case scan, photo, link, typeIt }

    private var entitled: Bool { env.subscription.entitlement.canUseScanner }

    var body: some View {
        NavigationStack(path: $path) {
            hub
                .navigationDestination(for: AddProductRoute.self) { route in
                    switch route {
                    case .link:
                        LinkImportView(model: model,
                                       startImport: { address in startImport(address) },
                                       retryAnalysis: { c in retryAnalysis(c) },
                                       cancel: { cancelWork() },
                                       typeItIn: { typeItIn() })
                    case .photo:
                        PhotoImportView(model: model,
                                        takePhoto: { showCamera = true },
                                        retryAnalysis: { c in retryAnalysis(c) },
                                        cancel: { cancelWork() },
                                        typeItIn: { typeItIn() })
                    }
                }
                .navigationDestination(for: AppDestination.self) { d in
                    switch d {
                    case .verdict(let id): VerdictView(scanID: id, fromScanner: true)
                    case .productForm(let mode): ProductFormView(mode: mode, attachScanID: attachScanID(for: mode))
                    case .productDetail(let id): ProductDetailView(productID: id)
                    default: EmptyView()
                    }
                }
        }
        .tint(SKColor.primary)
        .fullScreenCover(isPresented: $showScanner) {
            ScannerHostView(embedded: false)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                guard let image else { return }
                model.reset()
                work?.cancel()
                work = Task { await model.scanPhoto(image) }
                if path.isEmpty { path.append(AddProductRoute.photo) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $paywall) { PaywallView(reason: $0) }
        .environment(\.openPaywall, OpenPaywallAction { paywall = $0 })
        .onChange(of: model.phase) { _, phase in
            if case .result(let id) = phase {
                verdictDepth = path.count + 1
                path.append(AppDestination.verdict(scanID: id))
            }
        }
        .onChange(of: path.count) { _, depth in
            if let d = verdictDepth, depth < d {
                verdictDepth = nil
                model.reset()
            }
        }
    }

    // MARK: Hub

    private var hub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("Add a product")
                        .font(SKFont.hero)
                        .foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("The quickest ways read the ingredient list for you and check it straight away.")
                        .font(SKFont.sans(16, relativeTo: .body))
                        .foregroundStyle(SKColor.muted)
                }
                .padding(.bottom, SKSpace.sm)

                AddOptionRow(art: .drop("DropScanner"), title: "Scan a barcode",
                             subtitle: "Point the camera at the bars on the pack", locked: !entitled) { choose(.scan) }
                AddOptionRow(art: .symbol("text.viewfinder"), title: "Photograph the label",
                             subtitle: "For a product without a barcode", locked: !entitled) { choose(.photo) }
                AddOptionRow(art: .symbol("link"), title: "Paste a product link",
                             subtitle: "From the brand's or a shop's page", locked: !entitled) { choose(.link) }
                AddOptionRow(art: .symbol("keyboard"), title: "Type it in",
                             subtitle: "Name, how your skin reacted, the ingredient list", locked: false) { choose(.typeIt) }

                if !entitled {
                    Text("Scan, photo and link import are part of Skintel+. Typing a product in is free.")
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .padding(.top, SKSpace.xs)
                }
            }
            .skPagePadding()
            .padding(.top, SKSpace.md)
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }.font(SKFont.bodyMedium)
            }
        }
    }

    /// Scan, photo and link keep the scanner's gate exactly (`canUseScanner`, else the
    /// `.scanner` paywall); typing it in keeps the free shelf limit.
    private func choose(_ choice: Choice) {
        Haptics.tap()
        switch choice {
        case .scan:
            if entitled { showScanner = true } else { paywall = .scanner }
        case .photo:
            guard entitled else { paywall = .scanner; return }
            if !model.isBusy { model.reset() }
            switch CameraPermission.status {
            // The page explains how to turn the camera back on.
            case .denied, .restricted: path.append(AddProductRoute.photo)
            case .authorized, .notDetermined: showCamera = true
            }
        case .link:
            guard entitled else { paywall = .scanner; return }
            if !model.isBusy { model.reset() }
            path.append(AddProductRoute.link)
        case .typeIt:
            typeItIn()
        }
    }

    private func typeItIn() {
        guard env.subscription.entitlement.canAddProduct(currentCount: env.products.products.count) else {
            paywall = .productLimit
            return
        }
        path.append(AppDestination.productForm(.add(prefill: nil)))
    }

    // MARK: Work

    private func startImport(_ address: String) {
        work?.cancel()
        work = Task { await model.importURL(address) }
    }

    private func retryAnalysis(_ candidate: ScanCandidate) {
        work?.cancel()
        work = Task { await model.analyze(candidate) }
    }

    private func cancelWork() {
        work?.cancel()
        work = nil
        model.reset()
    }

    /// Only the verdict's "Save to shelf" (which carries a prefill) saves that scan with the product.
    private func attachScanID(for mode: ProductFormMode) -> String? {
        guard case .add(let prefill) = mode, prefill != nil, case .result(let id) = model.phase else { return nil }
        return id
    }
}

/// One of the hub's four large choices. At most one drop per screen, so only the barcode row
/// gets the illustration; the others use a symbol tile.
private struct AddOptionRow: View {
    enum Art {
        case drop(String)
        case symbol(String)
    }

    let art: Art
    let title: String
    let subtitle: String
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SKSpace.lg) {
                artwork
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: SKSpace.sm) {
                        Text(title)
                            .font(SKFont.cardTitle)
                            .foregroundStyle(SKColor.ink)
                            .multilineTextAlignment(.leading)
                        if locked { SkintelPlusBadge() }
                    }
                    Text(subtitle)
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SKColor.muted)
                    .accessibilityHidden(true)
            }
            .padding(SKSpace.lg)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
            .contentShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(locked ? "Part of Skintel+" : "")
    }

    @ViewBuilder
    private var artwork: some View {
        switch art {
        case .drop(let name):
            SKDrop(name, size: 64)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SKColor.primary)
                .frame(width: 52, height: 52)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// Small "Skintel+" tag on options a free account can see but that need the subscription.
struct SkintelPlusBadge: View {
    var body: some View {
        Text("Skintel+")
            .font(SKFont.chip)
            .foregroundStyle(SKColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(SKColor.blush, in: Capsule())
            .fixedSize()
    }
}
