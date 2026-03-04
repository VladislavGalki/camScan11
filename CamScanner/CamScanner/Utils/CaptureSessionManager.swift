import AVFoundation
import CoreMotion
import Foundation
import UIKit

private struct RectangleDetectorResult {
    let rectangle: Quadrilateral
    let imageSize: CGSize
}

protocol CaptureSessionManagerDelegate: NSObjectProtocol {
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager)
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize)
    func captureSessionManager(
        _ captureSessionManager: CaptureSessionManager,
        didCapturePicture picture: UIImage,
        withQuad quad: Quadrilateral?
    )
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error)
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQRCode code: String)
}

final class CaptureSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let videoPreviewLayer: AVCaptureVideoPreviewLayer
    private let captureSession = AVCaptureSession()
    private let rectangleFunnel = RectangleFeaturesFunnel()
    weak var delegate: CaptureSessionManagerDelegate?
    private var displayedRectangleResult: RectangleDetectorResult?
    private var photoOutput = AVCapturePhotoOutput()

    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "capture_session_queue")
    
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isQRDetecting = false
    
    private var currentFlashMode: FlashMode = .auto
    
    private var isDetecting = true

    private var noRectangleCount = 0
    private let noRectangleThreshold = 3

    // MARK: - Throttling Vision

    private let detectionMinInterval: CFTimeInterval = 0.10
    private var lastDetectionTime: CFTimeInterval = 0
    private var isVisionInFlight = false

    // MARK: - Camera selection

    private func selectBackCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first
    }

    private func applyDefaultUltraWideZoomIfNeeded() {
        guard let device = videoDeviceInput?.device else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.deviceType == .builtInUltraWideCamera {
                let desired: CGFloat = 1.15
                let clamped = min(max(desired, device.minAvailableVideoZoomFactor),
                                  device.maxAvailableVideoZoomFactor)
                device.videoZoomFactor = clamped
            } else {
                // wide camera — keep neutral
                device.videoZoomFactor = 1.0
            }
        } catch {}
    }

    // MARK: Life Cycle

    init?(videoPreviewLayer: AVCaptureVideoPreviewLayer, delegate: CaptureSessionManagerDelegate? = nil) {
        self.videoPreviewLayer = videoPreviewLayer

        if delegate != nil {
            self.delegate = delegate
        }

        super.init()

        guard let device = selectBackCamera() else {
            let error = ImageScannerControllerError.inputDevice
            delegate?.captureSessionManager(self, didFailWithError: error)
            return nil
        }

        // IMPORTANT: make sure focus/torch uses the same chosen device
        CaptureSession.current.device = device

        captureSession.beginConfiguration()

        photoOutput.isHighResolutionCaptureEnabled = true

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true

        defer {
            device.unlockForConfiguration()
            captureSession.commitConfiguration()
        }

        guard let deviceInput = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(photoOutput),
              captureSession.canAddOutput(videoOutput),
              captureSession.canAddOutput(metadataOutput)
        else {
            let error = ImageScannerControllerError.inputDevice
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }

        self.videoDeviceInput = deviceInput

        do {
            try device.lockForConfiguration()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }

        device.isSubjectAreaChangeMonitoringEnabled = true

        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            metadataOutput.metadataObjectTypes = []
        }
        
        metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        let photoPreset = AVCaptureSession.Preset.photo

        if captureSession.canSetSessionPreset(photoPreset) {
            captureSession.sessionPreset = photoPreset

            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
            }
        }

        videoPreviewLayer.session = captureSession
        videoPreviewLayer.videoGravity = .resizeAspectFill

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video_ouput_queue"))
    }
    
    deinit {
        print("!!! CaptureSessionManager deinit")
    }

    // MARK: Capture Session Life Cycle

    internal func start(mode: FlashMode) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            sessionQueue.async { [weak self] in
                guard let self else { return }

                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.applyDefaultUltraWideZoomIfNeeded()
                    }
                }

                DispatchQueue.main.async {
                    self.isDetecting = true
                }
                
                setTorch(mode: mode)
            }

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.start(mode: mode) }
                    else {
                        let error = ImageScannerControllerError.authorization
                        self.delegate?.captureSessionManager(self, didFailWithError: error)
                    }
                }
            }

        default:
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let error = ImageScannerControllerError.authorization
                self.delegate?.captureSessionManager(self, didFailWithError: error)
            }
        }
    }

    internal func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    internal func setTorch(mode: FlashMode) {
        currentFlashMode = mode
        
        guard let device = videoDeviceInput?.device,
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            switch mode {
            case .on:
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                
            case .off, .auto:
                device.torchMode = .off
            }

        } catch {
            print("Torch error:", error)
        }
    }
    
    internal func resumeDetection() {
        DispatchQueue.main.async { [weak self] in
            self?.isDetecting = true
            self?.rectangleFunnel.currentAutoScanPassCount = 0
        }
    }

    internal func pauseDetection() {
        DispatchQueue.main.async { [weak self] in
            self?.isDetecting = false
        }
    }
    
    internal func setQRDetecting(_ enabled: Bool) {
        isQRDetecting = enabled
    }

    internal func capturePhoto() {
        guard let connection = photoOutput.connection(with: .video), connection.isEnabled, connection.isActive else {
            let error = ImageScannerControllerError.capture
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }
        
        CaptureSession.current.setImageOrientation()
        
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.isAutoStillImageStabilizationEnabled = true
        
        if let device = videoDeviceInput?.device, device.hasFlash {
            switch currentFlashMode {
            case .on:
                photoSettings.flashMode = .off
            case .off:
                photoSettings.flashMode = .off
            case .auto:
                photoSettings.flashMode = .auto
            }
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isDetecting,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let now = CACurrentMediaTime()
        guard !isVisionInFlight, (now - lastDetectionTime) >= detectionMinInterval else { return }

        isVisionInFlight = true
        lastDetectionTime = now

        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                               height: CVPixelBufferGetHeight(pixelBuffer))

        VisionRectangleDetector.rectangle(forPixelBuffer: pixelBuffer) { [weak self] rectangle in
            guard let self else { return }
            self.processRectangle(rectangle: rectangle, imageSize: imageSize)
            self.isVisionInFlight = false
        }
    }

    private func processRectangle(rectangle: Quadrilateral?, imageSize: CGSize) {
        if let rectangle {
            self.noRectangleCount = 0
            self.rectangleFunnel
                .add(rectangle, currentlyDisplayedRectangle: self.displayedRectangleResult?.rectangle) { [weak self] result, rectangle in
                    guard let self else { return }
                    self.displayRectangleResult(rectangleResult: RectangleDetectorResult(rectangle: rectangle, imageSize: imageSize))
                }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.noRectangleCount += 1

                if self.noRectangleCount > self.noRectangleThreshold {
                    self.rectangleFunnel.currentAutoScanPassCount = 0
                    self.displayedRectangleResult = nil
                    
                    self.delegate?.captureSessionManager(self, didDetectQuad: nil, imageSize)
                }
            }
            return
        }
    }

    @discardableResult private func displayRectangleResult(rectangleResult: RectangleDetectorResult) -> Quadrilateral {
        displayedRectangleResult = rectangleResult

        let quad = rectangleResult.rectangle.toCartesian(withHeight: rectangleResult.imageSize.height)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.captureSessionManager(self, didDetectQuad: quad, rectangleResult.imageSize)
        }

        return quad
    }
}

extension CaptureSessionManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ captureOutput: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                     previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?
    ) {
        if let error {
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }

        isDetecting = false
        rectangleFunnel.currentAutoScanPassCount = 0
        delegate?.didStartCapturingPicture(for: self)

        if let sampleBuffer = photoSampleBuffer,
           let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
            forJPEGSampleBuffer: sampleBuffer,
            previewPhotoSampleBuffer: nil
           ) {
            completeImageCapture(with: imageData)
        } else {
            let error = ImageScannerControllerError.capture
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }

        isDetecting = false
        rectangleFunnel.currentAutoScanPassCount = 0
        delegate?.didStartCapturingPicture(for: self)

        if let imageData = photo.fileDataRepresentation() {
            completeImageCapture(with: imageData)
        } else {
            let error = ImageScannerControllerError.capture
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }
    }

    private func completeImageCapture(with imageData: Data) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let image = UIImage(data: imageData) else {
                let error = ImageScannerControllerError.capture
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.delegate?.captureSessionManager(self, didFailWithError: error)
                }
                return
            }
            
            var angle: CGFloat = 0.0

            switch image.imageOrientation {
            case .right:
                angle = CGFloat.pi / 2
            case .up:
                angle = CGFloat.pi
            default:
                break
            }

            var quad: Quadrilateral?
            if let displayedRectangleResult = self?.displayedRectangleResult {
                quad = self?.displayRectangleResult(rectangleResult: displayedRectangleResult)
                quad = quad?.scale(displayedRectangleResult.imageSize, image.size, withRotationAngle: angle)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.delegate?.captureSessionManager(self, didCapturePicture: image, withQuad: quad)
            }
        }
    }
}

extension CaptureSessionManager: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard isQRDetecting else { return }
        
        for obj in metadataObjects {
            guard let qr = obj as? AVMetadataMachineReadableCodeObject,
                  qr.type == .qr,
                  let str = qr.stringValue,
                  !str.isEmpty else { continue }
            
            delegate?.captureSessionManager(self, didDetectQRCode: str)
            break
        }
    }
}
