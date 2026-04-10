import UIKit

final class OpenDocumentCarouselController: UIViewController {

    // MARK: Constants

    private let cardWidth: CGFloat = 322
    private let maxCardHeight: CGFloat = 456
    private let spacing: CGFloat = 16

    // MARK: Data

    private let pageIndicator = PaddedLabel()
    private var models: [ScanPreviewModel]
    private var textItems: [DocumentTextItem]
    private var watermarkItems: [DocumentWatermarkItem]
    private var signatureItems: [DocumentSignatureItem]
    private var collectionView: UICollectionView!

    private var currentIndex: Int = 0

    private let onPageChanged: (Int) -> Void
    private let onRotatePage: (Int) -> Void
    private let onCellHeightChanged: (CGFloat) -> Void

    // MARK: Init

    init(
        models: [ScanPreviewModel],
        textItems: [DocumentTextItem],
        watermarkItems: [DocumentWatermarkItem] = [],
        signatureItems: [DocumentSignatureItem] = [],
        onPageChanged: @escaping (Int) -> Void,
        onRotatePage: @escaping (Int) -> Void,
        onCellHeightChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.models = models
        self.textItems = textItems
        self.watermarkItems = watermarkItems
        self.signatureItems = signatureItems
        self.onPageChanged = onPageChanged
        self.onRotatePage = onRotatePage
        self.onCellHeightChanged = onCellHeightChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollection()
        updateIndicator(index: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHorizontalInsets()
        updateVerticalInsets()
        onCellHeightChanged(collectionView.bounds.height)
    }

    // MARK: Public

    func update(
        _ newModels: [ScanPreviewModel],
        textItems newTextItems: [DocumentTextItem],
        watermarkItems newWatermarkItems: [DocumentWatermarkItem] = [],
        signatureItems newSignatureItems: [DocumentSignatureItem] = []
    ) {
        let didModelsChange = models != newModels
        let didTextItemsChange = textItems != newTextItems
        let didWatermarkItemsChange = watermarkItems != newWatermarkItems
        let didSignatureItemsChange = signatureItems != newSignatureItems

        models = newModels
        textItems = newTextItems
        watermarkItems = newWatermarkItems
        signatureItems = newSignatureItems

        if didModelsChange {
            collectionView.reloadData()
            currentIndex = min(currentIndex, max(models.count - 1, 0))
            updateIndicator(index: currentIndex)
        } else if didTextItemsChange || didWatermarkItemsChange || didSignatureItemsChange {
            updateVisibleOverlays()
        }
    }

    func handleBottomBarAction(_ action: ScanPreviewBottomBarAction) {
        switch action {
        case .rotate:
            rotateCurrentPage()
        case .deletePage(let index):
            handlePageDeletion(at: index)
        }
    }

    // MARK: Private

    private func rotateCurrentPage() {
        onRotatePage(currentIndex)
    }

    private func handlePageDeletion(at index: Int) {
        let targetIndex = min(index, models.count - 1)

        guard targetIndex >= 0 else { return }

        let indexPath = IndexPath(item: targetIndex, section: 0)

        collectionView.scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: true
        )

        currentIndex = targetIndex
        updateIndicator(index: targetIndex)
    }
}

private extension OpenDocumentCarouselController {
    func cardHeight() -> CGFloat {
        let available = collectionView.bounds.height
        return min(maxCardHeight, available * 0.75)
    }

    func updateHorizontalInsets() {
        let inset = (collectionView.bounds.width - cardWidth) / 2

        guard collectionView.contentInset.left != inset ||
              collectionView.contentInset.right != inset else { return }

        collectionView.contentInset.left = inset
        collectionView.contentInset.right = inset
    }

    func updateVerticalInsets() {
        let height = cardHeight()
        let inset = max(0, (collectionView.bounds.height - height) / 2)

        guard collectionView.contentInset.top != inset ||
              collectionView.contentInset.bottom != inset else { return }

        collectionView.contentInset.top = inset
        collectionView.contentInset.bottom = inset
    }

    func updateIndicator(index: Int) {
        guard !models.isEmpty else { return }
        pageIndicator.text = "\(index + 1)/\(models.count)"
    }

    func updateVisibleOverlays() {
        for cell in collectionView.visibleCells {
            guard let pageCell = cell as? OpenDocumentPageCell,
                  let indexPath = collectionView.indexPath(for: pageCell) else { continue }

            let pageTextItems = textItems.filter { $0.pageIndex == indexPath.item }
            let pageWatermarkItems = watermarkItems.filter { $0.pageIndex == indexPath.item }
            let pageSignatureItems = signatureItems.filter { $0.pageIndex == indexPath.item }
            pageCell.updateOverlays(textItems: pageTextItems, watermarkItems: pageWatermarkItems, signatureItems: pageSignatureItems)
        }
    }
}

private extension OpenDocumentCarouselController {
    func setupCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast
        collectionView.clipsToBounds = false
        collectionView.layer.masksToBounds = false

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(
            OpenDocumentPageCell.self,
            forCellWithReuseIdentifier: OpenDocumentPageCell.reuseId
        )

        view.addSubview(collectionView)
        view.addSubview(pageIndicator)

        pageIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pageIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: -12),
            pageIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension OpenDocumentCarouselController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        models.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: OpenDocumentPageCell.reuseId,
            for: indexPath
        ) as? OpenDocumentPageCell else {
            return UICollectionViewCell()
        }

        let pageIndex = indexPath.item
        let pageTextItems = textItems.filter { $0.pageIndex == pageIndex }
        let pageWatermarkItems = watermarkItems.filter { $0.pageIndex == pageIndex }
        let pageSignatureItems = signatureItems.filter { $0.pageIndex == pageIndex }
        cell.configure(model: models[pageIndex], textItems: pageTextItems, watermarkItems: pageWatermarkItems, signatureItems: pageSignatureItems)

        cell.onZoomChanged = { [weak self] zoomed in
            self?.collectionView.isScrollEnabled = !zoomed
        }

        return cell
    }
}

extension OpenDocumentCarouselController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let height = collectionView.bounds.height
        return CGSize(width: cardWidth, height: height)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        let fullWidth = cardWidth + layout.minimumLineSpacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left

        let currentPage = offset / fullWidth
        let targetIndex: CGFloat

        if velocity.x > 0.2 {
            targetIndex = ceil(currentPage)
        } else if velocity.x < -0.2 {
            targetIndex = floor(currentPage)
        } else {
            targetIndex = round(currentPage)
        }

        let clampedIndex = max(
            0,
            min(targetIndex, CGFloat(collectionView.numberOfItems(inSection: 0) - 1))
        )

        let newOffset = clampedIndex * fullWidth - scrollView.contentInset.left
        targetContentOffset.pointee.x = newOffset
        
        currentIndex = Int(clampedIndex)
        onPageChanged(Int(clampedIndex))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let fullWidth = cardWidth + spacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left
        let rawIndex = Int(round(offset / fullWidth))
        let clampedIndex = max(0, min(rawIndex, models.count - 1))

        currentIndex = clampedIndex
        updateIndicator(index: clampedIndex)
    }
}
