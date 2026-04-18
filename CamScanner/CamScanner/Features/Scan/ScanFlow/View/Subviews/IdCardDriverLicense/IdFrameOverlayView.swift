//
//  IdFrameOverlayView.swift
//

import UIKit

final class IdFrameOverlayView: UIView {
    enum Layout: Equatable {
        case padded(horizontalPadding: CGFloat, verticalPadding: CGFloat, height: CGFloat)
        case aspectFit(horizontalPadding: CGFloat, verticalPadding: CGFloat, aspect: CGFloat, maxHeight: CGFloat? = nil)
        case square(size: CGFloat, verticalOffset: CGFloat = 0)
        case fixed(width: CGFloat, height: CGFloat, verticalOffset: CGFloat = 0)
    }
    
    private let gridLayer = CAShapeLayer()
    
    var layout: Layout = .padded(horizontalPadding: 16, verticalPadding: 90, height: 220) {
        didSet { setNeedsLayout() }
    }
    
    var title: String = "" {
        didSet {
            titleLabel.attributedText = makeTitleAttributed(title)
            setNeedsLayout()
        }
    }
    
    var guideImage: UIImage? {
        didSet {
            guideImageView.image = guideImage
            guideImageView.isHidden = (guideImage == nil)
            setNeedsLayout()
        }
    }

    var dimAlpha: CGFloat = 0.55 {
        didSet { setNeedsLayout() }
    }
    
    var showGrid = false {
        didSet {
            gridLayer.isHidden = !showGrid
        }
    }

    var onFrameChanged: ((CGRect) -> Void)?

    private(set) var frameRect: CGRect = .zero

    // MARK: - Layers

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 1
        l.textAlignment = .center
        l.backgroundColor = .clear
        return l
    }()
    
    private let guideImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.isHidden = true
        return iv
    }()
    
    private let dimLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear

        // dim
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(dimAlpha).cgColor
        layer.addSublayer(dimLayer)
        
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridLayer.lineWidth = 1
        gridLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(gridLayer)

        // stroke
        strokeLayer.fillColor = UIColor.clear.cgColor
        
        strokeLayer.strokeColor = UIColor(
            red: 0.0,
            green: 136.0 / 255.0,
            blue: 1.0,
            alpha: 1.0
        ).cgColor
        
        strokeLayer.lineWidth = 2
        layer.addSublayer(strokeLayer)
        
        addSubview(titleLabel)
        addSubview(guideImageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let newRect = computeFrameRect()
        if newRect != frameRect {
            frameRect = newRect
            onFrameChanged?(frameRect)
        }
        
        // MARK: - Title layout
        if !title.isEmpty {
            let titleHeight: CGFloat = 22
            let horizontalPadding: CGFloat = 12

            let maxWidth = bounds.width - 32
            let textWidth = min(
                maxWidth,
                titleLabel.intrinsicContentSize.width + horizontalPadding * 2
            )

            titleLabel.frame = CGRect(
                x: frameRect.midX - textWidth / 2,
                y: frameRect.minY - titleHeight - 8,
                width: textWidth,
                height: titleHeight
            )
        } else {
            titleLabel.frame = .zero
        }

        let fullPath = UIBezierPath(rect: bounds)
        let holePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 0)
        fullPath.append(holePath)
        fullPath.usesEvenOddFillRule = true

        dimLayer.fillRule = .evenOdd
        dimLayer.path = fullPath.cgPath
        dimLayer.fillColor = UIColor.black.withAlphaComponent(dimAlpha).cgColor

        guideImageView.frame = frameRect
        guideImageView.alpha = 1
        
        let hasGuide = (guideImage != nil)
        strokeLayer.isHidden = hasGuide
        
        if !hasGuide {
            strokeLayer.path = holePath.cgPath
            strokeLayer.fillColor = UIColor.clear.cgColor
            
            strokeLayer.strokeColor = UIColor(
                red: 0.0,
                green: 136.0 / 255.0,
                blue: 1.0,
                alpha: 1.0
            ).cgColor
            
            strokeLayer.lineWidth = 2
        }
        
        drawGrid(in: frameRect)
    }
    
    private func makeTitleAttributed(_ text: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 17, weight: .regular)

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        paragraph.alignment = .center

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white,
                .kern: -0.43,
                .paragraphStyle: paragraph
            ]
        )
    }
    
    private func drawGrid(in rect: CGRect) {
        guard rect != .zero else {
            gridLayer.path = nil
            return
        }

        let path = UIBezierPath()

        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3

        path.move(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + 2 * thirdWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 2 * thirdWidth, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight))

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 2 * thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2 * thirdHeight))

        gridLayer.path = path.cgPath
    }

    private func computeFrameRect() -> CGRect {
        let b = bounds

        switch layout {

        case let .padded(horizontalPadding, verticalPadding, height):
            let availableWidth = max(1, b.width - 2 * horizontalPadding)
            let availableHeight = max(1, b.height - 2 * verticalPadding)
            let h = min(max(1, height), availableHeight)
            let w = availableWidth
            let x = horizontalPadding
            let y = verticalPadding + (availableHeight - h) / 2
            return CGRect(x: x, y: y, width: w, height: h).integral

        case let .aspectFit(horizontalPadding, verticalPadding, aspect, maxHeight):
            let availableWidth = max(1, b.width - 2 * horizontalPadding)
            let availableHeight = max(1, b.height - 2 * verticalPadding)

            var w = availableWidth
            var h = w / max(0.0001, aspect)

            if h > availableHeight {
                h = availableHeight
                w = h * aspect
            }

            if let maxHeight {
                h = min(h, maxHeight)
                w = h * aspect
            }

            let x = (b.width - w) / 2
            let y = (b.height - h) / 2
            return CGRect(x: x, y: y, width: w, height: h).integral

        case let .square(size, verticalOffset):
            let maxSide = min(b.width, b.height)
            let side = min(size, maxSide * 0.92)
            let x = (b.width - side) / 2
            let y = (b.height - side) / 2 + verticalOffset
            return CGRect(x: x, y: y, width: side, height: side).integral

        case let .fixed(width, height, verticalOffset):
            let safeWidth = min(width, b.width * 0.92)
            let safeHeight = min(height, b.height * 0.92)
            let x = (b.width - safeWidth) / 2
            let y = (b.height - safeHeight) / 2 + verticalOffset
            return CGRect(x: x, y: y, width: safeWidth, height: safeHeight).integral
        }
    }
}
