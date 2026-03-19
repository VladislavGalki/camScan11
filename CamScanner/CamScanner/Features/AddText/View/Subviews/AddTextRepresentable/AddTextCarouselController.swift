import UIKit

final class AddTextCarouselController: UIViewController {
    // MARK: - Constants

    private let cardWidth: CGFloat = 322
    private let maxCardHeight: CGFloat = 456
    private let spacing: CGFloat = 16

    // MARK: - UI

    private let pageIndicator = PaddedLabel()
    private var collectionView: UICollectionView!

    // MARK: - State

    private var models: [ScanPreviewModel]
    private var textItems: [DocumentTextItem]
    private var selectedTextID: UUID?
    private var currentIndex: Int = 0
    
    private var editingTextID: UUID?
    private var editingTextDraft: String

    // MARK: - Callbacks

    private let onPageChanged: (Int) -> Void
    private let onPageTap: (Int, CGPoint, CGSize) -> Void
    private let onTextTap: (UUID) -> Void
    private let onSelectedTextFrameChanged: (UUID, CGRect?) -> Void
    private let onTextMove: (UUID, CGPoint) -> Void
    private let onTextResize: (UUID, CGFloat, CGFloat?) -> Void
    private let onResizeStateChanged: (Bool) -> Void
    private let onEditingTextChanged: (String, CGSize) -> Void
    private let onEditingSubmit: () -> Void

    // MARK: - Init

    init(
        models: [ScanPreviewModel],
        textItems: [DocumentTextItem],
        selectedTextID: UUID?,
        editingTextID: UUID?,
        editingTextDraft: String,
        onPageChanged: @escaping (Int) -> Void,
        onPageTap: @escaping (Int, CGPoint, CGSize) -> Void,
        onTextTap: @escaping (UUID) -> Void,
        onSelectedTextFrameChanged: @escaping (UUID, CGRect?) -> Void,
        onTextMove: @escaping (UUID, CGPoint) -> Void,
        onTextResize: @escaping (UUID, CGFloat, CGFloat?) -> Void,
        onResizeStateChanged: @escaping (Bool) -> Void,
        onEditingTextChanged: @escaping (String, CGSize) -> Void,
        onEditingSubmit: @escaping () -> Void
    ) {
        self.models = models
        self.textItems = textItems
        self.selectedTextID = selectedTextID
        self.editingTextID = editingTextID
        self.editingTextDraft = editingTextDraft
        self.onPageChanged = onPageChanged
        self.onPageTap = onPageTap
        self.onTextTap = onTextTap
        self.onSelectedTextFrameChanged = onSelectedTextFrameChanged
        self.onTextMove = onTextMove
        self.onTextResize = onTextResize
        self.onResizeStateChanged = onResizeStateChanged
        self.onEditingTextChanged = onEditingTextChanged
        self.onEditingSubmit = onEditingSubmit
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
        textItems newTextItems: [DocumentTextItem],
        selectedTextID newSelectedTextID: UUID?,
        editingTextID newEditingTextID: UUID?,
        editingTextDraft newEditingTextDraft: String
    ) {
        let didModelsChange = models != newModels
        let didTextItemsChange = textItems != newTextItems
        let didSelectionChange = selectedTextID != newSelectedTextID
        let didEditingIDChange = editingTextID != newEditingTextID
        let didEditingDraftChange = editingTextDraft != newEditingTextDraft

        models = newModels
        textItems = newTextItems
        selectedTextID = newSelectedTextID
        editingTextID = newEditingTextID
        editingTextDraft = newEditingTextDraft

        if didModelsChange {
            collectionView.reloadData()
            updateIndicator(index: min(currentIndex, max(newModels.count - 1, 0)))
            return
        }

        if didTextItemsChange ||
            didSelectionChange ||
            didEditingIDChange ||
            didEditingDraftChange {
            updateVisibleOverlays()
            updateIndicator(index: min(currentIndex, max(newModels.count - 1, 0)))
        }
    }
}

// MARK: - Private

private extension AddTextCarouselController {
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
            AddTextPageCell.self,
            forCellWithReuseIdentifier: AddTextPageCell.reuseId
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

    func updateVisibleOverlays() {
        for cell in collectionView.visibleCells {
            guard let pageCell = cell as? AddTextPageCell,
                  let indexPath = collectionView.indexPath(for: pageCell),
                  models.indices.contains(indexPath.item) else { continue }

            pageCell.updateOverlay(
                pageIndex: indexPath.item,
                textItems: textItems.filter { $0.pageIndex == indexPath.item },
                selectedTextID: selectedTextID,
                editingTextID: editingTextID,
                editingTextDraft: editingTextDraft,
                onPageTap: { [weak self] point, initialSize in
                    self?.onPageTap(indexPath.item, point, initialSize)
                },
                onTextTap: { [weak self] id in
                    self?.onTextTap(id)
                },
                onTextMove: { [weak self] id, center in
                    self?.onTextMove(id, center)
                },
                onTextResize: { [weak self] id, width, centerX in
                    self?.onTextResize(id, width, centerX)
                },
                onResizeStateChanged: { [weak self] value in
                    self?.onResizeStateChanged(value)
                },
                onEditingTextChanged: { [weak self] text, size in
                    self?.onEditingTextChanged(text, size)
                },
                onEditingSubmit: { [weak self] in
                    self?.onEditingSubmit()
                }
            )
        }
    }
}

// MARK: - UICollectionViewDataSource

extension AddTextCarouselController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        models.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AddTextPageCell.reuseId,
            for: indexPath
        ) as? AddTextPageCell else {
            return UICollectionViewCell()
        }

        cell.configure(
            model: models[indexPath.item],
            pageIndex: indexPath.item,
            textItems: textItems.filter { $0.pageIndex == indexPath.item },
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft,
            parent: self,
            onPageTap: { [weak self] point, initialSize in
                self?.onPageTap(indexPath.item, point, initialSize)
            },
            onTextTap: { [weak self] id in
                self?.onTextTap(id)
            },
            onTextMove: { [weak self] id, center in
                self?.onTextMove(id, center)
            },
            onTextResize: { [weak self] id, width, centerX in
                self?.onTextResize(id, width, centerX)
            },
            onResizeStateChanged: { [weak self] value in
                self?.onResizeStateChanged(value)
            },
            onSelectedTextFrameChanged: { [weak self] id, rect in
                guard let self else { return }

                guard let rect else {
                    self.onSelectedTextFrameChanged(id, nil)
                    return
                }

                guard let window = self.view.window else { return }

                let rectInController = cell.contentView.convert(rect, to: self.view)
                let rectInWindow = self.view.convert(rectInController, to: window)

                self.onSelectedTextFrameChanged(id, rectInWindow)
            },
            onEditingTextChanged: { [weak self] text, size in
                self?.onEditingTextChanged(text, size)
            },
            onEditingSubmit: { [weak self] in
                self?.onEditingSubmit()
            }
        )

        cell.onZoomChanged = { [weak self] zoomed in
            self?.collectionView.isScrollEnabled = !zoomed
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension AddTextCarouselController: UICollectionViewDelegateFlowLayout {
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

        let clampedIndex = max(
            0,
            min(targetIndex, CGFloat(collectionView.numberOfItems(inSection: 0) - 1))
        )

        let newOffset = clampedIndex * fullWidth - scrollView.contentInset.left
        targetContentOffset.pointee.x = newOffset
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
