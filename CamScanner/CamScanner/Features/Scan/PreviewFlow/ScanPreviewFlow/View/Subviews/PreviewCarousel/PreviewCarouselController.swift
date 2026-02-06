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
        models = newModels
        collectionView.reloadData()
    }
    
    func handleBottomBarAction(_ action: ScanPreviewBottomBarAction) {
        switch action {
        case .rotate:
            rotateCurrentPage()
        }
    }
    
    private func rotateCurrentPage() {
        onRotatePage(currentIndex)
        
        
        guard models.indices.contains(currentIndex) else { return }
        var model = models[currentIndex]

        model.frames = model.frames.map {
            RotationService.shared.rotateRight(frame: $0)
        }

        models[currentIndex] = model
        collectionView.reloadItems(at: [IndexPath(item: currentIndex, section: 0)])
    }
}

// MARK: - Layout Helpers

private extension PreviewCarouselController {

    func cardHeight() -> CGFloat {
        let available = collectionView.bounds.height
        return min(maxCardHeight, available * 0.75)
    }
    
    func updateHorizontalInsets() {
        guard collectionView.collectionViewLayout is UICollectionViewFlowLayout else { return }

        let cardWidth: CGFloat = cardWidth
        let inset = (collectionView.bounds.width - cardWidth) / 2

        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: inset,
            bottom: 0,
            right: inset
        )
    }

    func updateVerticalInsets() {
        let height = cardHeight()
        let inset = max(0, (collectionView.bounds.height - height) / 2)

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
        models.count + 1
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if indexPath.item == models.count {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: PreviewAddPageCell.reuseId,
                for: indexPath
            )
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

        let cardWidth: CGFloat = cardWidth
        let spacing = layout.minimumLineSpacing
        let fullWidth = cardWidth + spacing

        let offset = targetContentOffset.pointee.x + scrollView.contentInset.left
        let index = round(offset / fullWidth)

        let newOffset = index * fullWidth - scrollView.contentInset.left
        targetContentOffset.pointee.x = newOffset

        onPageChanged(Int(index))
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
