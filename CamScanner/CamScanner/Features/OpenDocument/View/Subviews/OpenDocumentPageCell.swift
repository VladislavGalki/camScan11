import UIKit
import SwiftUI

final class OpenDocumentPageCell: UICollectionViewCell, UIScrollViewDelegate {

    static let reuseId = "OpenDocumentPageCell"

    // MARK: Views

    private let scrollView = UIScrollView()
    private let zoomContainerView = UIView()
    private let stackView = UIStackView()

    private let imageView1 = UIImageView()
    private let imageView2 = UIImageView()

    private var image1WidthConstraint: NSLayoutConstraint?
    private var image1HeightConstraint: NSLayoutConstraint?
    private var image2WidthConstraint: NSLayoutConstraint?
    private var image2HeightConstraint: NSLayoutConstraint?

    private var overlayHostingController: UIHostingController<OpenDocumentCombinedOverlayView>?

    var onZoomChanged: ((Bool) -> Void)?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 0

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 4
        layer.shadowOffset = .zero

        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setup() {
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [imageView1, imageView2].forEach {
            $0.contentMode = .scaleAspectFit
            $0.clipsToBounds = true
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(scrollView)
        scrollView.addSubview(zoomContainerView)
        zoomContainerView.addSubview(stackView)

        stackView.addArrangedSubview(imageView1)
        stackView.addArrangedSubview(imageView2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = contentView.bounds
        zoomContainerView.frame = scrollView.bounds

        if stackView.superview != nil, stackView.constraints.isEmpty {
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: zoomContainerView.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: zoomContainerView.centerYAnchor)
            ])
        }

        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 0
        ).cgPath
    }

    // MARK: Configure

    func configure(model: ScanPreviewModel, textItems: [DocumentTextItem] = [], watermarkItems: [DocumentWatermarkItem] = [], signatureItems: [DocumentSignatureItem] = []) {
        scrollView.zoomScale = 1

        imageView1.isHidden = true
        imageView2.isHidden = true

        image1WidthConstraint?.isActive = false
        image1HeightConstraint?.isActive = false
        image2WidthConstraint?.isActive = false
        image2HeightConstraint?.isActive = false

        let previews = model.frames.compactMap { $0.preview }

        switch model.documentType {
        case .documents:
            guard let image = previews.first else { return }

            imageView1.isHidden = false
            imageView1.image = image

            image1WidthConstraint = imageView1.widthAnchor.constraint(equalTo: zoomContainerView.widthAnchor)
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

            image1WidthConstraint?.isActive = true
            image1HeightConstraint?.isActive = true
            image2WidthConstraint?.isActive = true
            image2HeightConstraint?.isActive = true

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

        updateOverlays(textItems: textItems, watermarkItems: watermarkItems, signatureItems: signatureItems)
        layoutIfNeeded()
    }

    func updateTextOverlay(textItems: [DocumentTextItem]) {
        updateOverlays(textItems: textItems, watermarkItems: [])
    }

    func updateOverlays(
        textItems: [DocumentTextItem],
        watermarkItems: [DocumentWatermarkItem],
        signatureItems: [DocumentSignatureItem] = []
    ) {
        let overlay = OpenDocumentCombinedOverlayView(textItems: textItems, watermarkItems: watermarkItems, signatureItems: signatureItems)

        if let overlayHostingController {
            overlayHostingController.rootView = overlay
        } else {
            let hosting = UIHostingController(rootView: overlay)
            hosting.view.backgroundColor = .clear
            hosting.view.isUserInteractionEnabled = false
            hosting.view.translatesAutoresizingMaskIntoConstraints = false

            overlayHostingController = hosting
            zoomContainerView.addSubview(hosting.view)

            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: zoomContainerView.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: zoomContainerView.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: zoomContainerView.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: zoomContainerView.trailingAnchor)
            ])
        }
    }

    // MARK: Zoom

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomContainerView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        onZoomChanged?(scrollView.zoomScale > 1.01)
        centerZoomContainer()
    }

    private func centerZoomContainer() {
        let bounds = scrollView.bounds
        var frame = zoomContainerView.frame

        if frame.size.width < bounds.width {
            frame.origin.x = (bounds.width - frame.width) / 2
        } else {
            frame.origin.x = 0
        }

        if frame.size.height < bounds.height {
            frame.origin.y = (bounds.height - frame.height) / 2
        } else {
            frame.origin.y = 0
        }

        zoomContainerView.frame = frame
    }
}
