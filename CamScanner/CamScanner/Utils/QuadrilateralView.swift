import AVFoundation
import Foundation
import UIKit

enum CornerPosition: CaseIterable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
}

final class QuadrilateralView: UIView {
    private let dimLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillRule = .evenOdd
        l.fillColor = UIColor(white: 0.0, alpha: 0.6).cgColor
        l.isHidden = true
        return l
    }()

    private let quadLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1).cgColor
        layer.fillColor = UIColor.red.cgColor
        layer.lineWidth = 2.0
        layer.opacity = 1.0
        layer.isHidden = true

        return layer
    }()

    private let quadView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) var quad: Quadrilateral?

    public var editable = false {
        didSet {
            cornerViews(hidden: !editable)
            quadLayer.fillColor = editable ? UIColor(white: 0.0, alpha: 0.6).cgColor : UIColor(white: 1.0, alpha: 0.5).cgColor
            guard let quad else {
                return
            }
            drawQuad(quad, animated: false)
            layoutCornerViews(forQuad: quad)
        }
    }

    public var strokeColor: CGColor? {
        didSet {
            quadLayer.strokeColor = strokeColor
        }
    }

    private var isHighlighted = false {
        didSet (oldValue) {
            guard oldValue != isHighlighted else {
                return
            }
            quadLayer.fillColor = isHighlighted ? UIColor.clear.cgColor : UIColor(white: 0.0, alpha: 0.6).cgColor
            if isHighlighted {
                bringSubviewToFront(quadView)
            } else {
                sendSubviewToBack(quadView)
            }
        }
    }

    private lazy var topLeftCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .topLeft)
    }()

    private lazy var topRightCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .topRight)
    }()

    private lazy var bottomRightCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .bottomRight)
    }()

    private lazy var bottomLeftCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .bottomLeft)
    }()

    private let highlightedCornerViewSize = CGSize(width: 75.0, height: 75.0)
    private let cornerViewSize = CGSize(width: 20.0, height: 20.0)

    // MARK: - Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        addSubview(quadView)
        setupCornerViews()
        setupConstraints()
        quadView.layer.addSublayer(dimLayer)
        quadView.layer.addSublayer(quadLayer)
    }

    private func setupConstraints() {
        let quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: topAnchor),
            quadView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            trailingAnchor.constraint(equalTo: quadView.trailingAnchor)
        ]

        NSLayoutConstraint.activate(quadViewConstraints)
    }

    private func setupCornerViews() {
        addSubview(topLeftCornerView)
        addSubview(topRightCornerView)
        addSubview(bottomRightCornerView)
        addSubview(bottomLeftCornerView)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        dimLayer.frame = bounds
        quadLayer.frame = bounds

        if let quad {
            drawQuadrilateral(quad: quad, animated: false)
        }
    }

    // MARK: - Drawings
    func drawQuadrilateral(quad: Quadrilateral, animated: Bool) {
        self.quad = quad
        drawQuad(quad, animated: animated)
        if editable {
            cornerViews(hidden: false)
            layoutCornerViews(forQuad: quad)
        }
    }

    private func drawQuad(_ quad: Quadrilateral, animated: Bool) {
        if animated {
            let anim = CABasicAnimation(keyPath: "path")
            anim.duration = 0.2
            quadLayer.add(anim, forKey: "path")
        }

        quadLayer.path = quad.path.cgPath
        quadLayer.strokeColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1).cgColor
        quadLayer.fillColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 0.1).cgColor
        quadLayer.lineWidth = 2.0
        quadLayer.isHidden = false

        if editable {
            let full = UIBezierPath(rect: bounds)
            let hole = UIBezierPath(cgPath: quad.path.cgPath)
            full.append(hole)
            full.usesEvenOddFillRule = true

            dimLayer.path = full.cgPath
            dimLayer.fillRule = .evenOdd
            dimLayer.fillColor = UIColor(white: 0.0, alpha: 0.6).cgColor
            dimLayer.isHidden = false
        } else {
            dimLayer.path = nil
            dimLayer.fillColor = UIColor(white: 0.0, alpha: 0.6).cgColor
            dimLayer.isHidden = true
        }
    }

    private func layoutCornerViews(forQuad quad: Quadrilateral) {
        topLeftCornerView.center = quad.topLeft
        topRightCornerView.center = quad.topRight
        bottomLeftCornerView.center = quad.bottomLeft
        bottomRightCornerView.center = quad.bottomRight
    }

    func removeQuadrilateral() {
        quadLayer.path = nil
        quadLayer.isHidden = true
    }

    // MARK: - Actions

    func moveCorner(cornerView: EditScanCornerView, atPoint point: CGPoint) {
        guard let quad else { return }

        let validPoint = self.validPoint(point, forCornerViewOfSize: cornerView.bounds.size, inView: self)
        cornerView.center = validPoint

        let updatedQuad = update(quad, withPosition: validPoint, forCorner: cornerView.position)
        self.quad = updatedQuad

        quadLayer.path = updatedQuad.path.cgPath
        quadLayer.strokeColor = strokeColor ?? UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1).cgColor
        quadLayer.fillColor = UIColor.clear.cgColor
        quadLayer.isHidden = false

        if editable {
            let full = UIBezierPath(rect: bounds)
            let hole = UIBezierPath(cgPath: updatedQuad.path.cgPath)
            full.append(hole)
            full.usesEvenOddFillRule = true
            dimLayer.path = full.cgPath
            dimLayer.fillRule = .evenOdd
            dimLayer.fillColor = UIColor(white: 0.0, alpha: 0.6).cgColor
            dimLayer.isHidden = false
        }

        layoutCornerViews(forQuad: updatedQuad)
    }

    private func resetHighlightedCornerView(cornerView: EditScanCornerView) {
        cornerView.reset()
        let origin = CGPoint(x: cornerView.frame.origin.x + (cornerView.frame.size.width - cornerViewSize.width) / 2.0,
                             y: cornerView.frame.origin.y + (cornerView.frame.size.height - cornerViewSize.width) / 2.0)
        cornerView.frame = CGRect(origin: origin, size: cornerViewSize)
        cornerView.setNeedsDisplay()
    }

    // MARK: Validation
    
    private func validPoint(_ point: CGPoint, forCornerViewOfSize cornerViewSize: CGSize, inView view: UIView) -> CGPoint {
        var validPoint = point

        if point.x > view.bounds.width {
            validPoint.x = view.bounds.width
        } else if point.x < 0.0 {
            validPoint.x = 0.0
        }

        if point.y > view.bounds.height {
            validPoint.y = view.bounds.height
        } else if point.y < 0.0 {
            validPoint.y = 0.0
        }

        return validPoint
    }

    // MARK: - Convenience

    private func cornerViews(hidden: Bool) {
        topLeftCornerView.isHidden = hidden
        topRightCornerView.isHidden = hidden
        bottomRightCornerView.isHidden = hidden
        bottomLeftCornerView.isHidden = hidden
    }

    private func update(_ quad: Quadrilateral, withPosition position: CGPoint, forCorner corner: CornerPosition) -> Quadrilateral {
        var quad = quad

        switch corner {
        case .topLeft:
            quad.topLeft = position
        case .topRight:
            quad.topRight = position
        case .bottomRight:
            quad.bottomRight = position
        case .bottomLeft:
            quad.bottomLeft = position
        }

        return quad
    }

    func cornerViewForCornerPosition(position: CornerPosition) -> EditScanCornerView {
        switch position {
        case .topLeft:
            return topLeftCornerView
        case .topRight:
            return topRightCornerView
        case .bottomLeft:
            return bottomLeftCornerView
        case .bottomRight:
            return bottomRightCornerView
        }
    }
    
    func isPointInsideCorner(_ point: CGPoint) -> Bool {
        let corners = [
            cornerViewForCornerPosition(position: .topLeft),
            cornerViewForCornerPosition(position: .topRight),
            cornerViewForCornerPosition(position: .bottomRight),
            cornerViewForCornerPosition(position: .bottomLeft)
        ]

        return corners.contains { $0.frame.insetBy(dx: -20, dy: -20).contains(point) }
    }
}

// MARK: - Edit corner view
final class EditScanCornerView: UIView {

    let position: CornerPosition

    private let outerSize: CGFloat = 14
    private let innerSize: CGFloat = 10

    private lazy var outerCircleLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.white.cgColor
        return l
    }()

    private lazy var innerCircleLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1).cgColor
        return l
    }()

    private(set) var isHighlighted = false

    init(frame: CGRect, position: CornerPosition) {
        self.position = position
        super.init(frame: frame)

        backgroundColor = .clear

        layer.addSublayer(outerCircleLayer)
        outerCircleLayer.addSublayer(innerCircleLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let outerRect = CGRect(
            x: (bounds.width - outerSize) / 2,
            y: (bounds.height - outerSize) / 2,
            width: outerSize,
            height: outerSize
        )

        outerCircleLayer.frame = outerRect
        outerCircleLayer.path = UIBezierPath(ovalIn: outerCircleLayer.bounds).cgPath

        let innerRect = CGRect(
            x: (outerSize - innerSize) / 2,
            y: (outerSize - innerSize) / 2,
            width: innerSize,
            height: innerSize
        )

        innerCircleLayer.frame = innerRect
        innerCircleLayer.path = UIBezierPath(ovalIn: innerCircleLayer.bounds).cgPath

        CATransaction.commit()
    }

    func highlight() {
        isHighlighted = true
    }

    func reset() {
        isHighlighted = false
    }
}
