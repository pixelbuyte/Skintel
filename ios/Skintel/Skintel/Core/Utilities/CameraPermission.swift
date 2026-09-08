import AVFoundation
import UIKit

enum CameraPermission {
    enum Status { case notDetermined, authorized, denied }

    static var status: Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Presents the system prompt only when the status is undetermined.
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
