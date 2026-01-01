//
//  IdFrameOverlayView.swift
//

import UIKit

final class IdFrameOverlayView: UIView {

    enum Layout: Equatable {
        /// ✅ Единственный режим:
        /// - horizontalPadding: отступы слева/справа
        /// - verticalPadding: симметричные отступы сверху/снизу
        /// - height: высота рамки (ширина берётся по доступной ширине)
        case padded(horizontalPadding: CGFloat, verticalPadding: CGFloat, height: CGFloat)
    }

    // MARK: - Public

    var layout: Layout = .padded(horizontalPadding: 16, verticalPadding: 90, height: 220) {
        didSet { setNeedsLayout() }
    }

    var cornerRadius: CGFloat = 18 {
        didSet { setNeedsLayout() }
    }

    /// затемнение вокруг рамки
    var dimAlpha: CGFloat = 0.55 {
        didSet { setNeedsLayout() }
    }

    var title: String = "" {
        didSet { titleLabel.text = title }
    }

    /// Rect рамки в координатах этого view
    var onFrameChanged: ((CGRect) -> Void)?

    private(set) var frameRect: CGRect = .zero

    // MARK: - Layers

    private let dimLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        l.textAlignment = .center
        l.layer.masksToBounds = true
        return l
    }()

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

        // stroke
        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.strokeColor = UIColor.white.cgColor
        strokeLayer.lineWidth = 2
        layer.addSublayer(strokeLayer)

        addSubview(titleLabel)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let newRect = computeFrameRect()

        if newRect != frameRect {
            frameRect = newRect
            onFrameChanged?(frameRect)
        }

        // 1) dim path: full bounds + hole(frame)
        let fullPath = UIBezierPath(rect: bounds)
        let holePath = UIBezierPath(roundedRect: frameRect, cornerRadius: cornerRadius)
        fullPath.append(holePath)
        dimLayer.path = fullPath.cgPath
        dimLayer.fillColor = UIColor.black.withAlphaComponent(dimAlpha).cgColor

        // 2) stroke path
        let strokePath = UIBezierPath(roundedRect: frameRect, cornerRadius: cornerRadius)
        strokeLayer.path = strokePath.cgPath

        // 3) title badge
        let badgeHeight: CGFloat = 28
        let badgeWidth = min(260, max(120, frameRect.width - 24))
        titleLabel.frame = CGRect(
            x: frameRect.midX - badgeWidth / 2,
            y: frameRect.minY - badgeHeight - 8,
            width: badgeWidth,
            height: badgeHeight
        )
        titleLabel.layer.cornerRadius = badgeHeight / 2
    }

    private func computeFrameRect() -> CGRect {
        let b = bounds

        switch layout {
        case let .padded(horizontalPadding, verticalPadding, height):

            let availableWidth = max(1, b.width - 2 * horizontalPadding)
            let availableHeight = max(1, b.height - 2 * verticalPadding)

            // height не может быть больше доступной высоты
            let h = min(max(1, height), availableHeight)
            let w = availableWidth

            // по X — строго отступы
            let x = horizontalPadding

            // по Y — центрируем внутри "доступной" области
            let y = verticalPadding + (availableHeight - h) / 2

            return CGRect(x: x, y: y, width: w, height: h).integral
        }
    }
}
