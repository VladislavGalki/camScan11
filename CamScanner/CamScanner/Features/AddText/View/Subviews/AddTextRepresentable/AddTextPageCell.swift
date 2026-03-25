import UIKit
import SwiftUI

final class AddTextPageCell: UICollectionViewCell, UIScrollViewDelegate {
    static let reuseId = "AddTextPageCell"

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let zoomContainerView = UIView()
    private let stackView = UIStackView()

    private let imageView1 = UIImageView()
    private let imageView2 = UIImageView()

    // MARK: - Constraints

    private var image1WidthConstraint: NSLayoutConstraint?
    private var image1HeightConstraint: NSLayoutConstraint?
    private var image2WidthConstraint: NSLayoutConstraint?
    private var image2HeightConstraint: NSLayoutConstraint?

    // MARK: - State

    private var currentTextItems: [DocumentTextItem] = []
    private var currentSelectedTextID: UUID?
    private var overlayHostingController: UIHostingController<AddTextPageOverlayView>?

    // MARK: - Callbacks

    var onSelectedTextFrameChanged: ((UUID, CGRect?) -> Void)?
    var onZoomChanged: ((Bool) -> Void)?

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

        overlayHostingController?.view.removeFromSuperview()
        overlayHostingController = nil

        image1WidthConstraint?.isActive = false
        image1HeightConstraint?.isActive = false
        image2WidthConstraint?.isActive = false
        image2HeightConstraint?.isActive = false

        imageView1.image = nil
        imageView2.image = nil
        imageView1.isHidden = true
        imageView2.isHidden = true

        currentTextItems = []
        currentSelectedTextID = nil
        onSelectedTextFrameChanged = nil
        onZoomChanged = nil
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

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 0).cgPath
    }
}

// MARK: - Setup

private extension AddTextPageCell {
    func setup() {
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
}

// MARK: - Configure

extension AddTextPageCell {
    func configure(
        model: ScanPreviewModel,
        pageIndex: Int,
        textItems: [DocumentTextItem],
        selectedTextID: UUID?,
        editingTextID: UUID?,
        editingTextDraft: String,
        delegate: AddTextPageDelegate?,
        onSelectedTextFrameChanged: ((UUID, CGRect?) -> Void)?
    ) {
        self.onSelectedTextFrameChanged = onSelectedTextFrameChanged
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

        updateOverlay(
            pageIndex: pageIndex,
            textItems: textItems,
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft,
            delegate: delegate
        )
    }

    func updateOverlay(
        pageIndex: Int,
        textItems: [DocumentTextItem],
        selectedTextID: UUID?,
        editingTextID: UUID?,
        editingTextDraft: String,
        delegate: AddTextPageDelegate?
    ) {
        currentTextItems = textItems
        currentSelectedTextID = selectedTextID

        let overlay = AddTextPageOverlayView(
            pageIndex: pageIndex,
            items: textItems,
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft,
            delegate: delegate
        )

        if let overlayHostingController {
            overlayHostingController.rootView = overlay
        } else {
            let hosting = UIHostingController(rootView: overlay)
            hosting.view.backgroundColor = .clear
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

        layoutIfNeeded()
        reportSelectedTextFrameIfNeeded(textItems: textItems, selectedTextID: selectedTextID)
    }
}

// MARK: - Zoom

extension AddTextPageCell {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomContainerView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        onZoomChanged?(scrollView.zoomScale > 1.01)
        centerZoomContainer()
        reportSelectedTextFrameIfNeeded(textItems: currentTextItems, selectedTextID: currentSelectedTextID)
    }
}

// MARK: - Helpers

private extension AddTextPageCell {
    func centerZoomContainer() {
        let bounds = scrollView.bounds
        var frame = zoomContainerView.frame

        frame.origin.x = frame.size.width < bounds.width ? (bounds.width - frame.width) / 2 : 0
        frame.origin.y = frame.size.height < bounds.height ? (bounds.height - frame.height) / 2 : 0

        zoomContainerView.frame = frame
    }

    func reportSelectedTextFrameIfNeeded(textItems: [DocumentTextItem], selectedTextID: UUID?) {
        guard let selectedTextID,
              let item = textItems.first(where: { $0.id == selectedTextID }) else { return }

        let rectInZoomContainer = CGRect(
            x: item.centerX * zoomContainerView.bounds.width - (item.width * zoomContainerView.bounds.width) / 2,
            y: item.centerY * zoomContainerView.bounds.height - (item.height * zoomContainerView.bounds.height) / 2,
            width: item.width * zoomContainerView.bounds.width,
            height: item.height * zoomContainerView.bounds.height
        )

        let rectInContentView = zoomContainerView.convert(rectInZoomContainer, to: contentView)
        onSelectedTextFrameChanged?(selectedTextID, rectInContentView)
    }
}
