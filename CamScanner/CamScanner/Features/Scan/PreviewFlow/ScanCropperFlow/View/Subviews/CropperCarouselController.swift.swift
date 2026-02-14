import UIKit

final class CropperCarouselController: UIViewController {

    // MARK: Constants

    private let cardWidth: CGFloat = 322
    private let maxCardHeight: CGFloat = 456
    private let spacing: CGFloat = 16

    // MARK: Data

    private var models: [ScanPreviewModel]
    private var collectionView: UICollectionView!

    private var currentIndex: Int = 0

    private let onPageChanged: (Int) -> Void
    private var onQuadChanged: ((Int, Quadrilateral) -> Void)?

    // MARK: Init

    init(
        models: [ScanPreviewModel],
        onPageChanged: @escaping (Int) -> Void,
        onQuadChanged: @escaping (Int, Quadrilateral) -> Void
    ) {
        self.models = models
        self.onPageChanged = onPageChanged
        self.onQuadChanged = onQuadChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHorizontalInsets()
        updateVerticalInsets()
    }

    // MARK: Public

    func update(_ newModels: [ScanPreviewModel]) {
        if newModels != models {
            models = newModels
            collectionView.reloadData()
        }
    }
    
    // MARK: Private
    
    private func updateEditableStates() {
        for case let cell as CropperPageCell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            let editable = indexPath.item == currentIndex
            cell.setEditable(editable)
        }
    }
}

private extension CropperCarouselController {
    func cardHeight() -> CGFloat {
        let available = collectionView.bounds.height
        return min(maxCardHeight, available * 0.75)
    }

    func updateHorizontalInsets() {
        guard collectionView.collectionViewLayout is UICollectionViewFlowLayout else { return }

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
}

private extension CropperCarouselController {
    func setupCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing

        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.clipsToBounds = false
        collectionView.layer.masksToBounds = false

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(
            CropperPageCell.self,
            forCellWithReuseIdentifier: CropperPageCell.reuseId
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension CropperCarouselController: UICollectionViewDataSource {
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
            withReuseIdentifier: CropperPageCell.reuseId,
            for: indexPath
        ) as? CropperPageCell else {
            return UICollectionViewCell()
        }

        cell.configure(
            model: models[indexPath.item],
            parent: self,
            isEditable: indexPath.item == currentIndex,
            onQuadChanged: { [weak self] quad in
                self?.onQuadChanged?(indexPath.item, quad)
            }
        )
        
        return cell
    }
}

extension CropperCarouselController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        let height = collectionView.bounds.height
        return CGSize(width: cardWidth, height: height)
    }
}

extension CropperCarouselController {
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {

        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        let fullWidth = cardWidth + layout.minimumLineSpacing

        let offset = targetContentOffset.pointee.x + scrollView.contentInset.left
        let index = round(offset / fullWidth)

        let newOffset = index * fullWidth - scrollView.contentInset.left
        targetContentOffset.pointee.x = newOffset

        let intIndex = Int(index)

        currentIndex = intIndex
        onPageChanged(intIndex)
        updateEditableStates()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let fullWidth = cardWidth + spacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left

        let rawIndex = Int(round(offset / fullWidth))
        let clampedIndex = min(rawIndex, models.count - 1)

        currentIndex = clampedIndex
    }
}
