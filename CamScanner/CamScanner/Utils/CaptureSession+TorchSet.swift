import AVFoundation
import Foundation

extension CaptureSession {
    /// Set torch explicitly (WeScan provides only toggle).
    /// Returns the resulting state.
    func setTorch(enabled: Bool) -> FlashState {
        guard let device, device.isTorchAvailable else { return .unavailable }

        do {
            try device.lockForConfiguration()
        } catch {
            return .unknown
        }

        defer { device.unlockForConfiguration() }

        let desired: AVCaptureDevice.TorchMode = enabled ? .on : .off
        guard device.torchMode != desired else {
            return enabled ? .on : .off
        }

        device.torchMode = desired
        return enabled ? .on : .off
    }
}
