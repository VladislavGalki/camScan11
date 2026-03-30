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

    func updateEraseSettings(eraseColor: UIColor, brushSize: CGFloat) {
        canvasView.penColor = eraseColor
        canvasView.penWidth = brushSize
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
}
