import UIKit

final class ErasePageCell: UICollectionViewCell {
    static let reuseId = "ErasePageCell"

    // MARK: - UI

    private let stackView = UIStackView()
    private let imageView1 = UIImageView()
    private let imageView2 = UIImageView()
    private let canvasView = DrawingCanvasUIView()

    // MARK: - Constraints

    private var image1WidthConstraint: NSLayoutConstraint?
    private var image1HeightConstraint: NSLayoutConstraint?
    private var image2WidthConstraint: NSLayoutConstraint?
    private var image2HeightConstraint: NSLayoutConstraint?

    // MARK: - State

    private var pageIndex: Int = 0
    private weak var delegate: ErasePageDelegate?
    private var previousStrokeCount: Int = 0
    private var compositePreviewImage: UIImage?

    // MARK: - Callbacks

    var onDrawingBegan: (() -> Void)?
    var onDrawingEnded: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 4
        layer.shadowOffset = .zero

        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        image1WidthConstraint?.isActive = false
        image1HeightConstraint?.isActive = false
        image2WidthConstraint?.isActive = false
        image2HeightConstraint?.isActive = false
        imageView1.image = nil
        imageView2.image = nil
        imageView1.isHidden = true
        imageView2.isHidden = true
        canvasView.clearAll()
        canvasView.colorProvider = nil
        delegate = nil
        previousStrokeCount = 0
        onDrawingBegan = nil
        onDrawingEnded = nil
        compositePreviewImage = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        canvasView.frame = contentView.bounds

        if stackView.superview != nil, stackView.constraints.isEmpty {
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }

        contentView.layoutIfNeeded()
        stackView.layoutIfNeeded()

        let visibleRects = [imageView1, imageView2]
            .filter { !$0.isHidden && $0.image != nil }
            .map { imageView -> CGRect in
                let contentRect = Self.aspectFitContentRect(for: imageView)
                return imageView.convert(contentRect, to: contentView)
            }

        let compositeRect = visibleRects.reduce(into: CGRect.null) { partialResult, rect in
            partialResult = partialResult.union(rect)
        }

        canvasView.setImageRectInView(compositeRect.isNull ? .zero : compositeRect)

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 0).cgPath
    }

    // MARK: - Configure

    func configure(
        model: ScanPreviewModel,
        pageIndex: Int,
        strokes: [Stroke],
        isAutoColor: Bool,
        eraseColor: UIColor,
        brushSize: CGFloat,
        delegate: ErasePageDelegate?
    ) {
        self.pageIndex = pageIndex
        self.delegate = delegate

        scrollToDefaultState()
        configureImages(for: model)
        compositePreviewImage = makeCompositePreviewImage(for: model)

        canvasView.tool = .pen
        canvasView.penColor = eraseColor
        canvasView.penAlpha = 1.0
        canvasView.penWidth = brushSize
        canvasView.colorProvider = isAutoColor
            ? { [weak self] point in
                self?.sampleEraseColor(at: point) ?? eraseColor
            }
            : nil

        canvasView.setStrokes(strokes)
        previousStrokeCount = strokes.count

        canvasView.onStrokesChanged = { [weak self] newStrokes in
            guard let self else { return }
            if newStrokes.count > self.previousStrokeCount,
               let newStroke = newStrokes.last {
                self.delegate?.didCommitStroke(newStroke, onPage: self.pageIndex)
            }
            self.previousStrokeCount = newStrokes.count
        }

        canvasView.onTouchBegan = { [weak self] in
            self?.onDrawingBegan?()
        }

        canvasView.onTouchEnded = { [weak self] in
            self?.onDrawingEnded?()
        }

        setNeedsLayout()
    }

    func updateEraseSettings(isAutoColor: Bool, eraseColor: UIColor, brushSize: CGFloat) {
        canvasView.penColor = eraseColor
        canvasView.penWidth = brushSize
        canvasView.colorProvider = isAutoColor
            ? { [weak self] point in
                self?.sampleEraseColor(at: point) ?? eraseColor
            }
            : nil
    }

    func updateStrokes(_ strokes: [Stroke]) {
        canvasView.setStrokes(strokes)
        previousStrokeCount = strokes.count
    }
}

// MARK: - Setup

private extension ErasePageCell {
    func setup() {
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [imageView1, imageView2].forEach {
            $0.contentMode = .scaleAspectFit
            $0.clipsToBounds = true
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        canvasView.backgroundColor = .clear
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.tool = .pen

        contentView.addSubview(stackView)
        contentView.addSubview(canvasView)

        stackView.addArrangedSubview(imageView1)
        stackView.addArrangedSubview(imageView2)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    func scrollToDefaultState() {
        imageView1.isHidden = true
        imageView2.isHidden = true

        image1WidthConstraint?.isActive = false
        image1HeightConstraint?.isActive = false
        image2WidthConstraint?.isActive = false
        image2HeightConstraint?.isActive = false
    }

    func configureImages(for model: ScanPreviewModel) {
        let previews = model.frames.compactMap { $0.preview }

        switch model.documentType {
        case .documents:
            guard let image = previews.first else { return }
            imageView1.isHidden = false
            imageView1.image = image
            image1WidthConstraint = imageView1.widthAnchor.constraint(equalTo: contentView.widthAnchor)
            image1WidthConstraint?.isActive = true

        case .idCard, .driverLicense:
            imageView1.isHidden = false
            imageView2.isHidden = false
            imageView1.image = previews.first
            imageView2.image = previews.count > 1 ? previews[1] : nil

            let size = CGSize(width: 171, height: 108)
            image1WidthConstraint = imageView1.widthAnchor.constraint(equalToConstant: size.width)
            image1HeightConstraint = imageView1.heightAnchor.constraint(equalToConstant: size.height)
            image2WidthConstraint = imageView2.widthAnchor.constraint(equalToConstant: size.width)
            image2HeightConstraint = imageView2.heightAnchor.constraint(equalToConstant: size.height)

            [image1WidthConstraint, image1HeightConstraint,
             image2WidthConstraint, image2HeightConstraint].forEach { $0?.isActive = true }

        case .passport:
            guard let image = previews.first else { return }
            imageView1.isHidden = false
            imageView1.image = image

            let size = CGSize(width: 360, height: 250)
            image1WidthConstraint = imageView1.widthAnchor.constraint(equalToConstant: size.width)
            image1HeightConstraint = imageView1.heightAnchor.constraint(equalToConstant: size.height)
            image1WidthConstraint?.isActive = true
            image1HeightConstraint?.isActive = true

        case .qrCode:
            break
        }
    }

    static func aspectFitContentRect(for imageView: UIImageView) -> CGRect {
        guard let image = imageView.image,
              image.size.width > 0, image.size.height > 0,
              imageView.bounds.width > 0, imageView.bounds.height > 0 else {
            return imageView.bounds
        }
        let bounds = imageView.bounds
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let displayedSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        return CGRect(
            x: (bounds.width - displayedSize.width) / 2,
            y: (bounds.height - displayedSize.height) / 2,
            width: displayedSize.width,
            height: displayedSize.height
        )
    }

    func makeCompositePreviewImage(for model: ScanPreviewModel) -> UIImage? {
        let previews = model.frames.compactMap { $0.preview }
        let visiblePreviews = previews.prefix(2)

        guard !visiblePreviews.isEmpty else { return nil }

        let referenceWidth: CGFloat?
        switch model.documentType {
        case .idCard, .driverLicense:
            referenceWidth = 171
        case .passport:
            referenceWidth = 360
        case .documents, .qrCode:
            referenceWidth = nil
        }

        let layout = EraseCompositeLayout.make(
            documentType: model.documentType,
            images: Array(visiblePreviews),
            referenceWidth: referenceWidth
        )
        return layout.compositeImage(with: Array(visiblePreviews))
    }

    func sampleEraseColor(at normalizedPoint: CGPoint) -> UIColor? {
        guard let image = compositePreviewImage?.normalizedUp(),
              let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard width > 0, height > 0 else { return nil }

        let centerX = min(max(Int(round(normalizedPoint.x * CGFloat(width - 1))), 0), width - 1)
        let centerY = min(max(Int(round(normalizedPoint.y * CGFloat(height - 1))), 0), height - 1)

        let radius = max(2, min(width, height) / 120)
        let sampleRect = CGRect(
            x: max(0, centerX - radius),
            y: max(0, centerY - radius),
            width: min(width - max(0, centerX - radius), radius * 2 + 1),
            height: min(height - max(0, centerY - radius), radius * 2 + 1)
        ).integral

        guard let cropped = cgImage.cropping(to: sampleRect) else { return nil }

        let sampleWidth = Int(sampleRect.width)
        let sampleHeight = Int(sampleRect.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * sampleWidth
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * sampleHeight)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixelData,
                  width: sampleWidth,
                  height: sampleHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.draw(cropped, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var alphaSum: Double = 0
        var count: Double = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let alpha = Double(pixelData[offset + 3]) / 255

                guard alpha > 0.01 else { continue }

                rSum += Double(pixelData[offset]) * alpha
                gSum += Double(pixelData[offset + 1]) * alpha
                bSum += Double(pixelData[offset + 2]) * alpha
                alphaSum += alpha
                count += 1
            }
        }

        guard count > 0, alphaSum > 0 else { return nil }

        return UIColor(
            red: rSum / (alphaSum * 255),
            green: gSum / (alphaSum * 255),
            blue: bSum / (alphaSum * 255),
            alpha: 1
        )
    }
}
