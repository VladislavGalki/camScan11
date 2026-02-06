import AVFoundation
import UIKit

final class DocumentCropperViewController: UIViewController {
    var onCropped: ((DocumentCropperModel) -> Void)?

    private var image: UIImage
    private var autoQuadInImageSpace: Quadrilateral?
    private var quad: Quadrilateral
    
    private lazy var magnifier = CropMagnifierView(frame: CGRect(x: 20, y: 100, width: 100, height: 100))
    
    private var zoomGestureController: ZoomGestureController!
    private var panGesture: UILongPressGestureRecognizer?

    private var quadViewWidthConstraint = NSLayoutConstraint()
    private var quadViewHeightConstraint = NSLayoutConstraint()

    private(set) var isProcessing: Bool = false

    private lazy var imageView: UIImageView = {
        let v = UIImageView()
        v.clipsToBounds = true
        v.isOpaque = true
        v.image = image
        v.backgroundColor = .black
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var quadView: QuadrilateralView = {
        let v = QuadrilateralView()
        v.editable = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    init(cropperModel: DocumentCropperModel) {
        self.image = cropperModel.image
        self.autoQuadInImageSpace = cropperModel.autoQuad
        self.quad = cropperModel.autoQuad ?? Self.defaultQuad(allOfImage: cropperModel.image)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(imageView)
        view.addSubview(quadView)
        view.addSubview(magnifier)
        
        magnifier.isHidden = true

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: imageView.leadingAnchor)
        ])

        quadViewWidthConstraint = quadView.widthAnchor.constraint(equalToConstant: 0.0)
        quadViewHeightConstraint = quadView.heightAnchor.constraint(equalToConstant: 0.0)

        NSLayoutConstraint.activate([
            quadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            quadView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            quadViewWidthConstraint,
            quadViewHeightConstraint
        ])

        rebuildZoomController()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustQuadViewConstraints()
        displayQuad()
    }

    func setAllQuad() {
        quad = Self.defaultQuad(allOfImage: image)
        displayQuad()
    }

    func setAutoQuad() {
        quad = autoQuadInImageSpace ?? Self.defaultQuad(allOfImage: image)
        displayQuad()
    }

    func rotateLeft() { rotate90(direction: .left) }
    func rotateRight() { rotate90(direction: .right) }

    func commitCrop() {
        guard let (cropped, quadInImageSpace) = cropCurrentReturningQuad() else { return }
        onCropped?(DocumentCropperModel(image: cropped, autoQuad: quadInImageSpace))
    }

    enum RotationDirection { case left, right }

    private func rotate90(direction: RotationDirection) {
        guard !isProcessing else { return }
        isProcessing = true

        let oldImage = image
        let oldQuad = currentQuadInImageSpace() ?? quad
        let oldAuto = autoQuadInImageSpace

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let newImage = self.rotatedPixels90(oldImage, direction: direction) else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }

            let newQuad = oldQuad.rotated90(direction: direction, inImageOfSize: oldImage.size).reorganized()
            let newAuto = oldAuto?.rotated90(direction: direction, inImageOfSize: oldImage.size).reorganized()

            DispatchQueue.main.async {
                self.image = newImage
                self.imageView.image = newImage

                self.quad = newQuad
                self.autoQuadInImageSpace = newAuto

                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()

                self.adjustQuadViewConstraints()
                self.displayQuad()
                self.rebuildZoomController()

                self.isProcessing = false
            }
        }
    }

    private func rotatedPixels90(_ image: UIImage, direction: RotationDirection) -> UIImage? {
        let oldSize = image.size
        let newSize = CGSize(width: oldSize.height, height: oldSize.width)

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)

            switch direction {
            case .right: c.rotate(by: .pi / 2)
            case .left:  c.rotate(by: -.pi / 2)
            }

            c.translateBy(x: -oldSize.width / 2, y: -oldSize.height / 2)
            image.draw(in: CGRect(origin: .zero, size: oldSize))
        }
    }

    private func cropCurrentReturningQuad() -> (UIImage, Quadrilateral)? {
        guard let drawnQuad = quadView.quad,
              let ciImage = CIImage(image: image) else { return nil }

        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))

        let scaledQuad = drawnQuad.scale(quadView.bounds.size, image.size).reorganized()
        quad = scaledQuad

        var cartesian = scaledQuad.toCartesian(withHeight: image.size.height)
        cartesian.reorganize()

        let filtered = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesian.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesian.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesian.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesian.topRight)
        ])

        let cropped = UIImage.from(ciImage: filtered)
        return (cropped, scaledQuad)
    }

    private func currentQuadInImageSpace() -> Quadrilateral? {
        guard let drawnQuad = quadView.quad else { return nil }
        return drawnQuad.scale(quadView.bounds.size, image.size).reorganized()
    }

    private func displayQuad() {
        let imageSize = image.size
        let size = CGSize(width: quadViewWidthConstraint.constant, height: quadViewHeightConstraint.constant)
        let imageFrame = CGRect(origin: quadView.frame.origin, size: size)

        let scaleTransform = CGAffineTransform.scaleTransform(forSize: imageSize, aspectFillInSize: imageFrame.size)
        let transformed = quad.applyTransforms([scaleTransform])

        quadView.drawQuadrilateral(quad: transformed, animated: false)
    }

    private func adjustQuadViewConstraints() {
        let frame = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        quadViewWidthConstraint.constant = frame.size.width
        quadViewHeightConstraint.constant = frame.size.height
    }

    private func rebuildZoomController() {
        if let panGesture { view.removeGestureRecognizer(panGesture) }

        zoomGestureController = ZoomGestureController(
            image: image,
            quadView: quadView,
            magnifier: magnifier
        )
        
        let g = UILongPressGestureRecognizer(target: zoomGestureController,
                                             action: #selector(zoomGestureController.handle(pan:)))
        g.minimumPressDuration = 0
        view.addGestureRecognizer(g)
        panGesture = g
    }

    private static func defaultQuad(allOfImage image: UIImage, withOffset offset: CGFloat = 75) -> Quadrilateral {
        let tl = CGPoint(x: offset, y: offset)
        let tr = CGPoint(x: image.size.width - offset, y: offset)
        let br = CGPoint(x: image.size.width - offset, y: image.size.height - offset)
        let bl = CGPoint(x: offset, y: image.size.height - offset)
        return Quadrilateral(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
    }
}

private extension Quadrilateral {
    func rotated90(direction: DocumentCropperViewController.RotationDirection,
                   inImageOfSize size: CGSize) -> Quadrilateral {

        func rotRight(_ p: CGPoint) -> CGPoint {
            CGPoint(x: size.height - p.y, y: p.x)
        }

        func rotLeft(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.y, y: size.width - p.x)
        }

        let f = (direction == .right) ? rotRight : rotLeft

        return Quadrilateral(
            topLeft: f(topLeft),
            topRight: f(topRight),
            bottomRight: f(bottomRight),
            bottomLeft: f(bottomLeft)
        )
    }
}
