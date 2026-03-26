import UIKit

final class WatermarkCarouselController: UIViewController {
    // MARK: - Constants

    private let cardWidth: CGFloat = 322
    private let maxCardHeight: CGFloat = 456
    private let spacing: CGFloat = 16

    // MARK: - UI

    private let pageIndicator = PaddedLabel()
    private var collectionView: UICollectionView!

    // MARK: - State

    private var models: [ScanPreviewModel]
    private var watermarkItems: [DocumentWatermarkItem]
    private var selectedWatermarkID: UUID?
    private var editingWatermarkID: UUID?
    private var editingTextDraft: String
    private var currentIndex: Int = 0

    // MARK: - Delegate

    private weak var delegate: WatermarkPageDelegate?

    // MARK: - Init

    init(
        models: [ScanPreviewModel],
        watermarkItems: [DocumentWatermarkItem],
        selectedWatermarkID: UUID?,
        editingWatermarkID: UUID?,
        editingTextDraft: String,
        delegate: WatermarkPageDelegate?
    ) {
        self.models = models
        self.watermarkItems = watermarkItems
        self.selectedWatermarkID = selectedWatermarkID
        self.editingWatermarkID = editingWatermarkID
        self.editingTextDraft = editingTextDraft
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

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

    // MARK: - Public

    func update(
        models newModels: [ScanPreviewModel],
        watermarkItems newWatermarkItems: [DocumentWatermarkItem],
        selectedWatermarkID newSelectedWatermarkID: UUID?,
        editingWatermarkID newEditingWatermarkID: UUID?,
        editingTextDraft newEditingTextDraft: String,
        isScrollDisabled: Bool = false
    ) {
        let didModelsChange = models != newModels
        let didItemsChange = watermarkItems != newWatermarkItems
        let didSelectionChange = selectedWatermarkID != newSelectedWatermarkID
        let didEditingIDChange = editingWatermarkID != newEditingWatermarkID
        let didEditingDraftChange = editingTextDraft != newEditingTextDraft

        models = newModels
        watermarkItems = newWatermarkItems
        selectedWatermarkID = newSelectedWatermarkID
        editingWatermarkID = newEditingWatermarkID
        editingTextDraft = newEditingTextDraft

        collectionView.isScrollEnabled = (editingWatermarkID == nil) && !isScrollDisabled

        if didModelsChange {
            collectionView.reloadData()
            updateIndicator(index: min(currentIndex, max(newModels.count - 1, 0)))
            return
        }

        if didItemsChange || didSelectionChange || didEditingIDChange || didEditingDraftChange {
            updateVisibleOverlays()
            updateIndicator(index: min(currentIndex, max(newModels.count - 1, 0)))
        }
    }
}

// MARK: - Private

private extension WatermarkCarouselController {
    func cardHeight() -> CGFloat {
        let available = collectionView.bounds.height
        return min(maxCardHeight, available * 0.75)
    }

    func updateHorizontalInsets() {
        let inset = (collectionView.bounds.width - cardWidth) / 2
        guard collectionView.contentInset.left != inset
                || collectionView.contentInset.right != inset else { return }

        collectionView.contentInset.left = inset
        collectionView.contentInset.right = inset
    }

    func updateVerticalInsets() {
        let height = cardHeight()
        let inset = max(0, (collectionView.bounds.height - height) / 2)
        guard collectionView.contentInset.top != inset
                || collectionView.contentInset.bottom != inset else { return }

        collectionView.contentInset.top = inset
        collectionView.contentInset.bottom = inset
    }

    func updateIndicator(index: Int) {
        guard !models.isEmpty else { return }
        pageIndicator.text = "\(index + 1)/\(models.count)"
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
            WatermarkPageCell.self,
            forCellWithReuseIdentifier: WatermarkPageCell.reuseId
        )

        view.addSubview(collectionView)
        view.addSubview(pageIndicator)

        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        pageIndicator.isHidden = true

        NSLayoutConstraint.activate([
            pageIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: -12),
            pageIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func updateVisibleOverlays() {
        for cell in collectionView.visibleCells {
            guard let pageCell = cell as? WatermarkPageCell,
                  let indexPath = collectionView.indexPath(for: pageCell),
                  models.indices.contains(indexPath.item) else { continue }

            let pageItems = watermarkItems.filter { $0.pageIndex == indexPath.item }

            pageCell.updateOverlay(
                pageIndex: indexPath.item,
                watermarkItems: pageItems,
                selectedWatermarkID: selectedWatermarkID,
                editingWatermarkID: editingWatermarkID,
                editingTextDraft: editingTextDraft,
                delegate: delegate
            )
        }
    }
}

// MARK: - UICollectionViewDataSource

extension WatermarkCarouselController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        models.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: WatermarkPageCell.reuseId,
            for: indexPath
        ) as? WatermarkPageCell else {
            return UICollectionViewCell()
        }

        let pageItems = watermarkItems.filter { $0.pageIndex == indexPath.item }

        cell.configure(
            model: models[indexPath.item],
            pageIndex: indexPath.item,
            watermarkItems: pageItems,
            selectedWatermarkID: selectedWatermarkID,
            editingWatermarkID: editingWatermarkID,
            editingTextDraft: editingTextDraft,
            delegate: delegate,
            onSelectedWatermarkFrameChanged: { [weak self] id, rect in
                guard let self else { return }

                guard let rect else {
                    self.delegate?.didChangeSelectedWatermarkFrame(id: id, rect: nil)
                    return
                }

                guard let window = self.view.window else { return }

                let rectInController = cell.contentView.convert(rect, to: self.view)
                let rectInWindow = self.view.convert(rectInController, to: window)
                self.delegate?.didChangeSelectedWatermarkFrame(id: id, rect: rectInWindow)
            }
        )

        cell.onZoomChanged = { [weak self] zoomed in
            self?.collectionView.isScrollEnabled = !zoomed
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension WatermarkCarouselController: UICollectionViewDelegateFlowLayout {
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
        guard editingWatermarkID == nil else { return }
        delegate?.didStartScroll()
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
