import UIKit

final class PreviewCarouselController: UIViewController {
    
    // MARK: Constants
    
    private let cardWidth: CGFloat = 322
    private let maxCardHeight: CGFloat = 456
    private let spacing: CGFloat = 16
    
    // MARK: Data
    
    private let pageIndicator = PaddedLabel()
    private var models: [ScanPreviewModel]
    private var collectionView: UICollectionView!
    
    private var currentIndex: Int = 0
    
    private let onPageChanged: (Int) -> Void
    private let onRotatePage: (Int) -> Void
    private let onAddTapped: () -> Void
    
    // MARK: Init
    
    init(
        models: [ScanPreviewModel],
        onPageChanged: @escaping (Int) -> Void,
        onRotatePage: @escaping (Int) -> Void,
        onAddTapped: @escaping () -> Void
    ) {
        self.models = models
        self.onPageChanged = onPageChanged
        self.onRotatePage = onRotatePage
        self.onAddTapped = onAddTapped
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
    }
    
    // MARK: Public
    
    func update(_ newModels: [ScanPreviewModel]) {
        guard newModels != models else { return }
        models = newModels
        collectionView.reloadData()
    }
    
    func handleBottomBarAction(_ action: ScanPreviewBottomBarAction) {
        switch action {
        case .rotate:
            rotateCurrentPage()
        case let .deletePage(index):
            handlePageDeletion(at: index)
        }
    }
    
    private func rotateCurrentPage() {
        onRotatePage(currentIndex)
    }
    
    func handlePageDeletion(at index: Int) {
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
    
    // MARK: Private
    
    private var shouldShowAddCell: Bool {
        guard let first = models.first else { return false }
        return first.documentType != .idCard && first.documentType != .driverLicense
    }
}

// MARK: - Layout Helpers

private extension PreviewCarouselController {

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
    
    private func updateIndicator(index: Int) {
        guard models.isEmpty == false else { return }
        pageIndicator.text = "\(index + 1)/\(models.count)"
    }
}

// MARK: - Setup

private extension PreviewCarouselController {
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
            PreviewPageCell.self,
            forCellWithReuseIdentifier: PreviewPageCell.reuseId
        )

        collectionView.register(
            PreviewAddPageCell.self,
            forCellWithReuseIdentifier: PreviewAddPageCell.reuseId
        )

        view.addSubview(collectionView)
        view.addSubview(pageIndicator)

        pageIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pageIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: -12),
            pageIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7)
        ])

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

// MARK: - DataSource

extension PreviewCarouselController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return models.count + (shouldShowAddCell ? 1 : 0)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        if shouldShowAddCell && indexPath.item == models.count {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: PreviewAddPageCell.reuseId,
                for: indexPath
            )
        }

        guard indexPath.item < models.count else {
            return UICollectionViewCell()
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PreviewPageCell.reuseId,
            for: indexPath
        ) as? PreviewPageCell else {
            return UICollectionViewCell()
        }

        cell.configure(model: models[indexPath.item])

        cell.onZoomChanged = { [weak self] zoomed in
            self?.collectionView.isScrollEnabled = !zoomed
        }

        return cell
    }
}

// MARK: - DelegateFlowLayout

extension PreviewCarouselController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        let height = collectionView.bounds.height
        return CGSize(width: cardWidth, height: height)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if indexPath.item == models.count {
            onAddTapped()
        }
    }
    
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        let fullWidth = cardWidth + layout.minimumLineSpacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left

        let currentIndex = offset / fullWidth
        let targetIndex: CGFloat

        if velocity.x > 0.2 {
            targetIndex = ceil(currentIndex)
        } else if velocity.x < -0.2 {
            targetIndex = floor(currentIndex)
        } else {
            targetIndex = round(currentIndex)
        }

        let clampedIndex = max(0, min(targetIndex, CGFloat(collectionView.numberOfItems(inSection: 0) - 1)))
        let newOffset = clampedIndex * fullWidth - scrollView.contentInset.left

        targetContentOffset.pointee.x = newOffset
        onPageChanged(Int(clampedIndex))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let fullWidth = cardWidth + spacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left
        let rawIndex = Int(round(offset / fullWidth))
        let clampedIndex = min(rawIndex, models.count - 1)

        currentIndex = clampedIndex
        updateIndicator(index: clampedIndex)
    }
}
