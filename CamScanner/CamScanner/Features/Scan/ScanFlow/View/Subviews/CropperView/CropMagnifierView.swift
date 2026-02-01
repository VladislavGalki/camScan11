import UIKit

final class CropMagnifierView: UIView {

    private let imageView = UIImageView()
    private let quadStrokeLayer = CAShapeLayer()
    private var corner: CornerPosition?

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        layer.cornerRadius = frame.width / 2
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor

        imageView.contentMode = .scaleAspectFill
        imageView.frame = bounds
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(image: UIImage, corner: CornerPosition, quad: Quadrilateral) {
        imageView.image = image

        let cornerPoint: CGPoint
        switch corner {
        case .topLeft: cornerPoint = quad.topLeft
        case .topRight: cornerPoint = quad.topRight
        case .bottomLeft: cornerPoint = quad.bottomLeft
        case .bottomRight: cornerPoint = quad.bottomRight
        }

        let scale = bounds.width / 100.0
        let transform = CGAffineTransform(translationX: -cornerPoint.x + bounds.width/2,
                                          y: -cornerPoint.y + bounds.height/2)
            .scaledBy(x: scale, y: scale)

        let path = quad.path.copy() as? UIBezierPath
        path?.apply(transform)

        quadStrokeLayer.path = path?.cgPath
        quadStrokeLayer.strokeColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1).cgColor
        quadStrokeLayer.fillColor = UIColor.clear.cgColor
        quadStrokeLayer.lineWidth = 2
        if quadStrokeLayer.superlayer == nil {
            layer.addSublayer(quadStrokeLayer)
        }
    }
}
