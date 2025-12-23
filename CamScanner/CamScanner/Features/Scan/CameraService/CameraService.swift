import AVFoundation
import UIKit

final class CameraService: NSObject {

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?

    private var photoCompletion: ((UIImage?) -> Void)?
    private(set) var isConfigured = false

    // MARK: - Configuration

    func configureIfNeeded(completion: @escaping (Bool) -> Void) {
        sessionQueue.async {
            if self.isConfigured {
                DispatchQueue.main.async { completion(true) }
                return
            }

            let success = self.configureSession()
            self.isConfigured = success
            DispatchQueue.main.async { completion(success) }
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Ultra-wide preferred, fallback to wide
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )

        guard let device = discovery.devices.first else {
            session.commitConfiguration()
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            } else {
                session.commitConfiguration()
                return false
            }
        } catch {
            session.commitConfiguration()
            return false
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            if let device = videoDeviceInput?.device {
                let supported = device.activeFormat.supportedMaxPhotoDimensions
                if let best = supported.max(by: {
                    Int($0.width * $0.height) < Int($1.width * $1.height)
                }) {
                    photoOutput.maxPhotoDimensions = best
                }
            }

            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            session.commitConfiguration()
            return false
        }

        session.commitConfiguration()
        return true
    }

    // MARK: - Session

    func start() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Torch / Zoom

    func setTorch(enabled: Bool) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setUltraWidePreferredZoom(_ zoom: CGFloat) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.deviceType == .builtInUltraWideCamera {
                    device.videoZoomFactor = max(1.0, min(zoom, device.activeFormat.videoMaxZoomFactor))
                } else {
                    device.videoZoomFactor = 1.0
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: - Capture

    func capturePhoto(flashMode: FlashMode, completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()

            if let device = self.videoDeviceInput?.device, device.hasFlash {
                settings.flashMode = {
                    switch flashMode {
                    case .on: return .on
                    case .auto: return .auto
                    default: return .off
                    }
                }()
            }

            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .quality

            self.photoCompletion = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            DispatchQueue.main.async { self.photoCompletion?(nil) }
            self.photoCompletion = nil
            return
        }

        DispatchQueue.main.async {
            self.photoCompletion?(image)
            self.photoCompletion = nil
        }
    }
}
