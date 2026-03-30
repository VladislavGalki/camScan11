import UIKit

final class ErasePageCell: UICollectionViewCell {
    static let reuseId = "ErasePageCell"

    // MARK: - UI

    private let imageView = UIImageView()
    private let canvasView = DrawingCanvasUIView()

    // MARK: - State

    private var pageIndex: Int = 0
    private weak var delegate: ErasePageDelegate?
    private var previousStrokeCount: Int = 0

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
        imageView.image = nil
        canvasView.clearAll()
        canvasView.colorProvider = nil
        delegate = nil
        previousStrokeCount = 0
        onDrawingBegan = nil
        onDrawingEnded = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = contentView.bounds
        canvasView.frame = contentView.bounds

        let imageRect = aspectFitRect(
            imageSize: imageView.image?.size ?? .zero,
            in: contentView.bounds.size
        )
        canvasView.setImageRectInView(imageRect)

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

        let image = model.frames.first?.preview
        imageView.image = image

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
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        canvasView.backgroundColor = .clear
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.tool = .pen

        contentView.addSubview(imageView)
        contentView.addSubview(canvasView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func sampleEraseColor(at normalizedPoint: CGPoint) -> UIColor? {
        guard let image = imageView.image?.normalizedUp(),
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
