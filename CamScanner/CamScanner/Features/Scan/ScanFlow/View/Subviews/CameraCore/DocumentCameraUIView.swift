import AVFoundation
import UIKit

final class DocumentCameraUIView: UIView {

    // MARK: - Layer

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    // MARK: - Overlay

    private let quadView = QuadrilateralView()
    
    var isLiveDetectionEnabled: Bool = true {
        didSet {
            if !isLiveDetectionEnabled {
                clearQuad()
            }
        }
    }

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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }

    func clearQuad() {
        quadView.removeQuadrilateral()
    }

    func updateDetectedQuad(_ quad: Quadrilateral?, imageSize: CGSize) {
        guard isLiveDetectionEnabled else {
            quadView.removeQuadrilateral()
            return
        }

        guard let quad else {
            quadView.removeQuadrilateral()
            return
        }

        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        let scaleTransform = CGAffineTransform.scaleTransform(
            forSize: portraitImageSize,
            aspectFillInSize: quadView.bounds.size
        )
        let scaledImageSize = imageSize.applying(scaleTransform)
        let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        let translationTransform = CGAffineTransform.translateTransform(
            fromCenterOfRect: imageBounds,
            toCenterOfRect: quadView.bounds
        )

        let transforms = [scaleTransform, rotationTransform, translationTransform]
        let transformedQuad = quad.applyTransforms(transforms)

        let displayQuad = transformedQuad
            .scaled(aroundCenterBy: 1.05)
            .clamped(to: quadView.bounds)

        quadView.drawQuadrilateral(quad: displayQuad, animated: true)
    }
}
