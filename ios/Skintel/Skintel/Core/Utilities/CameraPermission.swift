import AVFoundation
import UIKit

enum CameraPermission {
    enum Status { case notDetermined, authorized, denied, restricted }

    static var status: Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    /// Presents the native system prompt only when the status is undetermined. Once the
    /// user has denied it (or a restriction applies), iOS won't show its own prompt again
    /// either — calling this repeatedly just re-reads the current status, it never nags.
    static func request() async -> Status {
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return status
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
