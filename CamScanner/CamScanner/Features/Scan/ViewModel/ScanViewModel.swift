import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {

    // MARK: - Camera (WeScan core)

    let camera = ScanCameraService()
    private var cancellables = Set<AnyCancellable>()

    // Последний quad из превью (координаты детектора) + размер imageSize детектора
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // MARK: - Auto shoot tuning (EMA + penalty)

    private var stableScore: Int = 0
    private var lastAutoShotAt: CFTimeInterval = 0

    // Area gate with hysteresis (enter/keep)
    private let minAreaEnter: CGFloat = 0.055
    private let minAreaKeep:  CGFloat = 0.045
    private var isAreaQualified = false

    // ✅ Stable “score” needed to shoot (was frames)
    private let requiredStableScore: Int = 5
    private let minShotInterval: CFTimeInterval = 1.2

    // ✅ Normalized thresholds (relative to quad bbox diagonal)
    private let maxCenterShiftNorm: CGFloat = 0.03   // 3% of diag
    private let maxAreaDeltaNorm: CGFloat = 0.12     // 12% change vs EMA area

    // EMA smoothing
    private var emaCenter: CGPoint? = nil
    private var emaArea: CGFloat? = nil
    private let emaCenterAlpha: CGFloat = 0.25
    private let emaAreaAlpha: CGFloat = 0.25

    // Optional: after a shot, give detector a brief calm-down (prevents spam / AVFoundation hiccups)
    private var coolDownUntil: CFTimeInterval = 0
    private let postShotCooldown: CFTimeInterval = 0.25

    // MARK: - Persisted settings used by UI

    @AppStorage(ScanSettingsKeys.grid) var grid: Bool = false
    @AppStorage(ScanSettingsKeys.autoShoot) var autoShoot: Bool = false
    @AppStorage(ScanSettingsKeys.autoCrop) var autoCrop: Bool = true
    @AppStorage(ScanSettingsKeys.textOrientationRotate) var textOrientationRotate: Bool = true
    @AppStorage(ScanSettingsKeys.volumeShutter) var volumeShutter: Bool = true

    // MARK: - UI state

    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single
    @Published var selectedDocumentType: DocumentType = .scan

    // MARK: - Capture result

    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var lastCaptured: UIImage? = nil
    @Published var groupCaptures: [UIImage] = []

    // MARK: - Lifecycle

    func onAppear() {
        bindCamera()
        camera.start()
    }

    func onDisappear() {
        camera.stop()
        camera.setTorch(enabled: false)
    }

    // MARK: - Bindings

    private func bindCamera() {
        guard cancellables.isEmpty else { return }

        camera.$authorizationDenied
            .receive(on: DispatchQueue.main)
            .sink { [weak self] denied in
                self?.showPermissionAlert = denied
            }
            .store(in: &cancellables)

        // ✅ получаем quad + imageSize вместе и на их основе решаем автоснимок
        camera.$lastDetectedQuad
            .combineLatest(camera.$lastImageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quad, size in
                guard let self else { return }
                self.latestPreviewQuad = quad
                self.latestPreviewImageSize = size
                self.handleAutoShoot(quad: quad, imageSize: size)
            }
            .store(in: &cancellables)

        camera.onCapture = { [weak self] image, _ in
            guard let self else { return }
            self.isCapturing = false

            var final = image

            // ✅ Кропаем по quad из превью (масштабируем в координаты photo + учитываем rotationAngle)
            if self.autoCrop,
               let previewQuad = self.latestPreviewQuad,
               self.latestPreviewImageSize.width > 0,
               self.latestPreviewImageSize.height > 0 {

                let angle = SmartCropper.rotationAngle(for: final.imageOrientation)
                let quadInImageSpace = previewQuad.scale(self.latestPreviewImageSize, final.size, withRotationAngle: angle)

                if let cropped = SmartCropper.cropAndDeskew(image: final, quad: quadInImageSpace) {
                    final = cropped
                }
            }

            // ✅ downscale ПОСЛЕ кропа
            final = final.downscaled(maxDimension: self.quality.maxDimension)

            switch self.captureMode {
            case .single:
                self.lastCaptured = final
            case .group:
                self.groupCaptures.append(final)
            }

            // After successful shot
            self.lastAutoShotAt = CACurrentMediaTime()
            self.coolDownUntil = self.lastAutoShotAt + self.postShotCooldown
            self.resetAutoShootState()
        }
    }

    // MARK: - Auto shoot (EMA + penalty)

    private func handleAutoShoot(quad: Quadrilateral?, imageSize: CGSize) {
        // автосъёмка только если включена
        guard autoShoot else {
            resetAutoShootState()
            return
        }

        // пока снимаем / показываем превью — не автофоткаем
        guard !isCapturing, lastCaptured == nil else {
            resetAutoShootState()
            return
        }

        let now = CACurrentMediaTime()
        guard now >= coolDownUntil else { return }

        guard let quad,
              imageSize.width > 0,
              imageSize.height > 0 else {
            // мягко деградируем, а не тотальный reset
            stableScore = max(0, stableScore - 1)
            return
        }

        var ordered = quad
        ordered.reorganize()

        // Bounding box metrics (in detector/image coordinates)
        let box = quadBoundingBox(ordered)
        let frameArea = max(imageSize.width * imageSize.height, 1)
        let boxArea = max(box.width * box.height, 0)
        let ratio = boxArea / frameArea

        // Hysteresis for area qualification
        if !isAreaQualified {
            isAreaQualified = ratio >= minAreaEnter
        } else {
            isAreaQualified = ratio >= minAreaKeep
        }

        print("📸 AutoShoot | area ratio = \(String(format: "%.4f", ratio)) | enter=\(minAreaEnter) keep=\(minAreaKeep) | qualified=\(isAreaQualified)")

        guard isAreaQualified else {
            // не сбрасываем всё, а мягко штрафуем
            stableScore = max(0, stableScore - 1)
            return
        }

        // Center + diag
        let center = CGPoint(x: box.midX, y: box.midY)
        let diag = max(hypot(box.width, box.height), 1)

        // EMA center
        if let c = emaCenter {
            emaCenter = CGPoint(
                x: c.x + emaCenterAlpha * (center.x - c.x),
                y: c.y + emaCenterAlpha * (center.y - c.y)
            )
        } else {
            emaCenter = center
        }
        let refCenter = emaCenter ?? center

        // center shift normalized (0..1)
        let centerShift = hypot(center.x - refCenter.x, center.y - refCenter.y)
        let centerShiftNorm = centerShift / diag

        // EMA area (use boxArea)
        if let a = emaArea {
            emaArea = a + emaAreaAlpha * (boxArea - a)
        } else {
            emaArea = boxArea
        }
        let refArea = max(emaArea ?? boxArea, 1)
        let areaDeltaNorm = abs(boxArea - refArea) / refArea

        // Stability checks
        let centerOk = centerShiftNorm <= maxCenterShiftNorm
        let areaOk = areaDeltaNorm <= maxAreaDeltaNorm

        // “Stable frame” if both are ok
        let isStableThisFrame = centerOk && areaOk

        // Penalty instead of reset
        if isStableThisFrame {
            stableScore += 1
        } else {
            // penalty severity
            let penalty: Int = {
                // very unstable center -> harsher
                if centerShiftNorm > (maxCenterShiftNorm * 2.0) { return 3 }
                // otherwise mild
                return 1
            }()
            stableScore = max(0, stableScore - penalty)
        }

        print("📸 AutoShoot | stable score = \(stableScore)/\(requiredStableScore) | centerShiftNorm=\(String(format: "%.3f", centerShiftNorm)) thr=\(String(format: "%.3f", maxCenterShiftNorm)) | areaΔ=\(String(format: "%.3f", areaDeltaNorm))")

        guard stableScore >= requiredStableScore else { return }
        guard (now - lastAutoShotAt) >= minShotInterval else {
            print("📸 AutoShoot | cooldown not passed: \(String(format: "%.2f", (now - lastAutoShotAt)))/\(minShotInterval)")
            return
        }

        print("📸 AutoShoot | 🔥 AUTO SHOT")

        // GO
        stableScore = 0
        capture()
    }

    private func resetAutoShootState() {
        stableScore = 0
        isAreaQualified = false
        emaCenter = nil
        emaArea = nil
    }

    // MARK: - Geometry helpers

    private func quadBoundingBox(_ q: Quadrilateral) -> CGRect {
        let xs = [q.topLeft.x, q.topRight.x, q.bottomRight.x, q.bottomLeft.x]
        let ys = [q.topLeft.y, q.topRight.y, q.bottomRight.y, q.bottomLeft.y]
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    // MARK: - Flash / torch

    func applyFlashSideEffects() {
        camera.setTorch(enabled: flashMode == .torch)
    }

    // MARK: - Capture

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        camera.capture()
    }

    func resetSingle() { lastCaptured = nil }
    func resetGroup() { groupCaptures.removeAll() }
}
