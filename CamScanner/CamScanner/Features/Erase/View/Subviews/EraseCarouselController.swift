import UIKit

final class EraseCarouselController: UIViewController {
    // MARK: - Constants

    private let cardWidth: CGFloat = 322
    private let spacing: CGFloat = 16

    // MARK: - UI

    private var collectionView: UICollectionView!

    // MARK: - State

    private var models: [ScanPreviewModel]
    private var strokes: [Stroke]
    private var eraseColor: UIColor
    private var brushSize: CGFloat
    private var currentIndex: Int = 0

    // MARK: - Delegate

    private weak var delegate: ErasePageDelegate?

    // MARK: - Init

    init(
        models: [ScanPreviewModel],
        strokes: [Stroke],
        eraseColor: UIColor,
        brushSize: CGFloat,
        delegate: ErasePageDelegate?
    ) {
        self.models = models
        self.strokes = strokes
        self.eraseColor = eraseColor
        self.brushSize = brushSize
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHorizontalInsets()
        updateVerticalInsets()
    }

    // MARK: - Public

    func update(
        models newModels: [ScanPreviewModel],
        strokes newStrokes: [Stroke],
        eraseColor newEraseColor: UIColor,
        brushSize newBrushSize: CGFloat,
        isScrollDisabled: Bool
    ) {
        let didModelsChange = models != newModels
        let didStrokesChange = strokes != newStrokes
        let didColorChange = eraseColor != newEraseColor
        let didBrushChange = brushSize != newBrushSize

        models = newModels
        strokes = newStrokes
        eraseColor = newEraseColor
        brushSize = newBrushSize

        collectionView.isScrollEnabled = !isScrollDisabled

        if didModelsChange {
            collectionView.reloadData()
            return
        }

        if didStrokesChange {
            updateVisibleStrokes()
        }

        if didColorChange || didBrushChange {
            updateVisibleSettings()
        }
    }
}

// MARK: - Private

private extension EraseCarouselController {
    func updateHorizontalInsets() {
        let inset = (collectionView.bounds.width - cardWidth) / 2
        guard collectionView.contentInset.left != inset
                || collectionView.contentInset.right != inset else { return }

        collectionView.contentInset.left = inset
        collectionView.contentInset.right = inset
    }

    func updateVerticalInsets() {
        let maxCardHeight: CGFloat = 456
        let height = min(maxCardHeight, collectionView.bounds.height * 0.75)
        let inset = max(0, (collectionView.bounds.height - height) / 2)
        guard collectionView.contentInset.top != inset
                || collectionView.contentInset.bottom != inset else { return }

        collectionView.contentInset.top = inset
        collectionView.contentInset.bottom = inset
    }

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
            ErasePageCell.self,
            forCellWithReuseIdentifier: ErasePageCell.reuseId
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func updateVisibleStrokes() {
        for cell in collectionView.visibleCells {
            guard let pageCell = cell as? ErasePageCell,
                  let indexPath = collectionView.indexPath(for: pageCell),
                  indexPath.item == currentIndex else { continue }
            pageCell.updateStrokes(strokes)
        }
    }

    func updateVisibleSettings() {
        for cell in collectionView.visibleCells {
            guard let pageCell = cell as? ErasePageCell else { continue }
            pageCell.updateEraseSettings(eraseColor: eraseColor, brushSize: brushSize)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension EraseCarouselController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        models.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ErasePageCell.reuseId,
            for: indexPath
        ) as? ErasePageCell else {
            return UICollectionViewCell()
        }

        cell.configure(
            model: models[indexPath.item],
            pageIndex: indexPath.item,
            strokes: indexPath.item == currentIndex ? strokes : [],
            eraseColor: eraseColor,
            brushSize: brushSize,
            delegate: delegate
        )

        cell.onDrawingBegan = { [weak self] in
            self?.collectionView.isScrollEnabled = false
        }

        cell.onDrawingEnded = { [weak self] in
            self?.collectionView.isScrollEnabled = true
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EraseCarouselController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: cardWidth, height: collectionView.bounds.height)
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

        let clampedIndex = max(0, min(targetIndex, CGFloat(collectionView.numberOfItems(inSection: 0) - 1)))
        let newOffset = clampedIndex * fullWidth - scrollView.contentInset.left
        targetContentOffset.pointee.x = newOffset

        delegate?.didChangePage(index: Int(clampedIndex))
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.didStartScroll()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let fullWidth = cardWidth + spacing
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left
        let rawIndex = Int(round(offset / fullWidth))
        let clampedIndex = max(0, min(rawIndex, models.count - 1))

        currentIndex = clampedIndex
    }
}
