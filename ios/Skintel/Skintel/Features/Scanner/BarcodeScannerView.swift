import AVFoundation
import SwiftUI
import UIKit

/// AVFoundation barcode reader (EAN-8/13, UPC-E, Code 128 — the formats on cosmetics).
/// Emits the code string through `onCode`; the model debounces. `paused` freezes the
/// session while a lookup or the found sheet is up.
struct BarcodeScannerView: UIViewRepresentable {
    var paused: Bool
    var torchOn: Bool
    let onCode: @MainActor (String) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        context.coordinator.attach(to: v)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onCode = onCode
        context.coordinator.setPaused(paused)
        context.coordinator.setTorch(torchOn)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: @MainActor (String) -> Void
        private let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "com.skintel.app.scanner", qos: .userInitiated)
        private var configured = false
        private var paused = false
        private var device: AVCaptureDevice?

        init(onCode: @escaping @MainActor (String) -> Void) {
            self.onCode = onCode
        }

        func attach(to view: PreviewView) {
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            queue.async { [self] in
                configureIfNeeded()
                if !session.isRunning { session.startRunning() }
            }
        }

        private func configureIfNeeded() {
            guard !configured else { return }
            configured = true
            session.beginConfiguration()
            session.sessionPreset = .high
            guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: cam),
                  session.canAddInput(input) else { session.commitConfiguration(); return }
            device = cam
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: queue)
                let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128, .code39]
                output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
            }
            // Cosmetics barcodes are small: focus continuously and let the lens get close.
            if (try? cam.lockForConfiguration()) != nil {
                if cam.isFocusModeSupported(.continuousAutoFocus) { cam.focusMode = .continuousAutoFocus }
                if cam.isAutoFocusRangeRestrictionSupported { cam.autoFocusRangeRestriction = .near }
                cam.unlockForConfiguration()
            }
            session.commitConfiguration()
        }

        func setPaused(_ p: Bool) {
            paused = p
        }

        func setTorch(_ on: Bool) {
            queue.async { [self] in
                guard let d = device, d.hasTorch, (try? d.lockForConfiguration()) != nil else { return }
                d.torchMode = on ? .on : .off
                d.unlockForConfiguration()
            }
        }

        func stop() {
            queue.async { [self] in
                if session.isRunning { session.stopRunning() }
                if let d = device, d.hasTorch, (try? d.lockForConfiguration()) != nil {
                    d.torchMode = .off
                    d.unlockForConfiguration()
                }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !paused,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            let handler = onCode
            Task { @MainActor in handler(value) }
        }
    }
}
