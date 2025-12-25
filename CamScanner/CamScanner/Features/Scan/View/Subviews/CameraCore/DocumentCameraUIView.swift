import AVFoundation
import UIKit

final class DocumentCameraUIView: UIView {

    // MARK: - Layer

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    // MARK: - Overlay

    private let quadView = QuadrilateralView()

    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView?

    private var subjectAreaObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .black

        // Match WeScan defaults.
        videoPreviewLayer.videoGravity = .resizeAspectFill

        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        addSubview(quadView)

        NSLayoutConstraint.activate([
            quadView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])

        // 1:1 with WeScan: reset focus when the camera reports a subject-area change.
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.AVCaptureDeviceSubjectAreaDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.subjectAreaDidChange()
        }
    }

    deinit {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
    }

    // MARK: - Focus (tap to focus)

    private func subjectAreaDidChange() {
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            // Ignore: upstream can surface errors if desired.
        }

        if let focusRectangle {
            CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        let convertedTouchPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)

        if let focusRectangle {
            CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        }

        let newFocus = FocusRectangleView(touchPoint: touchPoint)
        newFocus.setBorder(color: UIColor.white.cgColor)
        addSubview(newFocus)
        focusRectangle = newFocus

        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            // Ignore: upstream can surface errors if desired.
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }

    func clearQuad() {
        quadView.removeQuadrilateral()
    }

    /// Update quad overlay using WeScan's exact transform pipeline.
    func updateDetectedQuad(_ quad: Quadrilateral?, imageSize: CGSize) {
        guard let quad else {
            quadView.removeQuadrilateral()
            return
        }

        // 1:1 copy from WeScan CameraScannerViewController.didDetectQuad
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize,
                                                              aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds,
                                                                        toCenterOfRect: quadView.bounds)
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        let transformedQuad = quad.applyTransforms(transforms)

        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
}
