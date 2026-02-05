import UIKit

final class PreviewPageCell: UICollectionViewCell, UIScrollViewDelegate {

    static let reuseId = "PreviewPageCell"

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    var onZoomChanged: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 0
        contentView.layer.masksToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 4
        layer.shadowOffset = .zero

        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)

        scrollView.frame = contentView.bounds
        imageView.frame = scrollView.bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        imageView.frame = scrollView.bounds
        
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 0
        ).cgPath
    }

    func configure(image: UIImage?) {
        imageView.image = image
        scrollView.zoomScale = 1
    }

    // MARK: Zoom

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        onZoomChanged?(scrollView.zoomScale > 1.01)
        centerImage()
    }

    private func centerImage() {

        let bounds = scrollView.bounds
        var frame = imageView.frame

        if frame.size.width < bounds.size.width {
            frame.origin.x = (bounds.size.width - frame.size.width) / 2
        } else {
            frame.origin.x = 0
        }

        if frame.size.height < bounds.size.height {
            frame.origin.y = (bounds.size.height - frame.size.height) / 2
        } else {
            frame.origin.y = 0
        }

        imageView.frame = frame
    }
}
