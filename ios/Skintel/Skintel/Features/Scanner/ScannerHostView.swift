import PhotosUI
import SwiftUI
import SkintelCore

/// Design §08/§09. Full-bleed camera with the bracketed viewfinder and a breathing scan
/// line; "Type it" and "Photo of ingredients" as the escape hatches. Scanning is Pro on
/// the server (402), so free accounts see an honest locked state that still lets them add
/// products by hand.
struct ScannerHostView: View {
    /// true when hosted in the Scanner tab, false as the FAB's full-screen cover.
    let embedded: Bool

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScanFlowModel?
    @State private var permission: CameraPermission.Status = CameraPermission.status
    @State private var showManual = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var path: [AppDestination] = []
    @State private var localPaywall: PaywallReason?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let model {
                    if env.subscription.entitlement.canUseScanner {
                        scanner(model)
                    } else {
                        lockedState
                    }
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .navigationDestination(for: AppDestination.self) { d in
                switch d {
                case .verdict(let id): VerdictView(scanID: id, fromScanner: true)
                case .productForm(let mode): ProductFormView(mode: mode, attachScanID: currentScanID)
                case .productDetail(let id): ProductDetailView(productID: id)
                default: EmptyView()
                }
            }
        }
        .tint(SKColor.primary)
        .onAppear {
            if model == nil { model = ScanFlowModel(env: env) }
            permission = CameraPermission.status
        }
        .sheet(item: $localPaywall) { PaywallView(reason: $0) }
        .environment(\.openPaywall, OpenPaywallAction { localPaywall = $0 })
    }

    private var currentScanID: String? {
        if case .result(let id) = model?.phase { return id }
        return nil
    }

    // MARK: Camera surface

    private func scanner(_ model: ScanFlowModel) -> some View {
        ZStack {
            SKColor.scannerBg.ignoresSafeArea()

            if permission == .authorized {
                BarcodeScannerView(paused: model.phase != .scanning, torchOn: model.torchOn) { code in
                    model.handleBarcode(code)
                }
                .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                permissionState
            }

            VStack {
                HStack {
                    if !embedded {
                        SKGlassButton(systemImage: "xmark", label: "Close") { dismiss() }
                    }
                    Spacer()
                    if permission == .authorized {
                        SKGlassButton(systemImage: model.torchOn ? "bolt.fill" : "bolt", label: "Torch") { model.torchOn.toggle() }
                    }
                }
                .padding(.horizontal, SKSpace.lg)
                .padding(.top, SKSpace.sm)

                Spacer()

                if permission == .authorized {
                    ZStack {
                        ViewfinderBrackets(color: .white, lineWidth: 3.5, corner: 26, length: 34)
                            .frame(width: 290, height: 200)
                        ScanLine()
                    }
                    .accessibilityHidden(true)

                    Text(caption(model))
                        .font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, SKSpace.lg)
                        .animation(SKAnimation.ios(0.3), value: model.phase)
                }

                Spacer()

                HStack(spacing: SKSpace.md) {
                    glassPill("Type it", icon: "keyboard") { showManual = true }
                    glassPill("Photo of ingredients", icon: "doc.text") { showCamera = true }
                }
                .padding(.horizontal, SKSpace.xl)
                .padding(.bottom, embedded ? SKSpace.lg : SKSpace.xxl)
            }
        }
        .statusBarHidden(!embedded)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showManual) { ManualEntrySheet(model: model) }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                if let image { Task { await model.scanPhoto(image) } }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { isSheetPhase(model.phase) }, set: { if !$0 { model.reset() } })) {
            FoundSheet(model: model)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(SKColor.cream)
        }
        .onChange(of: model.phase) { _, phase in
            if case .result(let id) = phase { path.append(.verdict(scanID: id)) }
        }
        .onChange(of: path) { _, p in
            // Returning to the camera after the verdict re-arms scanning.
            if p.isEmpty, case .result = model.phase { model.reset() }
        }
        .task { permission = await CameraPermission.request() }
    }

    private func isSheetPhase(_ p: ScanFlowModel.Phase) -> Bool {
        switch p {
        case .lookingUp, .found, .analyzing, .notFound, .failed: true
        case .scanning, .result: false
        }
    }

    private func caption(_ model: ScanFlowModel) -> String {
        switch model.phase {
        case .scanning: "Point at the barcode on the back"
        case .lookingUp: "Looking it up…"
        default: "Hold on…"
        }
    }

    private func glassPill(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SKSpace.sm) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(.white.opacity(0.18)))
        }
        .buttonStyle(SKPressStyle())
    }

    // MARK: Permission / locked states

    private var permissionState: some View {
        VStack(spacing: SKSpace.lg) {
            Image(systemName: "camera").font(.system(size: 34, weight: .light)).foregroundStyle(.white)
            Text(permission == .denied ? "Camera is off for Skintel" : "Camera access")
                .font(SKFont.section).foregroundStyle(.white)
            Text(permission == .denied
                 ? "Turn it on in Settings to scan barcodes. You can still type a barcode or paste ingredients."
                 : "Skintel needs the camera to read barcodes.")
                .font(SKFont.secondary).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            if permission == .denied {
                SKButton(title: "Open Settings", kind: .secondary, fullWidth: false) { CameraPermission.openSettings() }
            }
        }
        .padding(SKSpace.xxl)
    }

    private var lockedState: some View {
        ZStack {
            SKColor.bg.ignoresSafeArea()
            VStack(spacing: SKSpace.lg) {
                if !embedded {
                    HStack { Button("Close") { dismiss() }.font(SKFont.bodyMedium); Spacer() }
                }
                Spacer()
                ScannerIllustration().frame(height: 200).frame(maxWidth: .infinity)
                Text("Scanning is a Pro feature").font(SKFont.section).foregroundStyle(SKColor.ink)
                Text("Barcode, label photo and link import all run through Skintel's AI. Free accounts can add up to five products by pasting the ingredient list.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
                SKButton(title: "See Skintel Pro") { openPaywall(.scanner) }
                SKButton(title: "Add a product by hand", kind: .secondary) { path.append(.productForm(.add(prefill: nil))) }
                Spacer()
            }
            .skPagePadding()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Terracotta line that breathes up and down inside the brackets.
private struct ScanLine: View {
    @State private var down = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [SKColor.primary.opacity(0), Color(hex: 0xE39A86), SKColor.primary.opacity(0)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 260, height: 3)
            .shadow(color: SKColor.primary.opacity(0.8), radius: 8)
            .offset(y: reduceMotion ? 0 : (down ? 62 : -62))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { down = true }
            }
    }
}

/// UIImagePickerController camera capture for label photos (rear camera, no editing).
struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: @MainActor (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.cameraCaptureMode = .photo
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: @MainActor (UIImage?) -> Void
        init(onImage: @escaping @MainActor (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            Task { @MainActor in onImage(img) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in onImage(nil) }
        }
    }
}
