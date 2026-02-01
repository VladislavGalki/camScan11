import UIKit

// MARK: - Model

struct CameraMode {
    let title: String
}

// MARK: - Cell

final class CameraModeCell: UICollectionViewCell {
    static let reuseId = "CameraModeCell"
    
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setup() {
        contentView.backgroundColor = .clear
        contentView.layer.masksToBounds = true
        contentView.layer.cornerCurve = .continuous
        
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.backgroundColor = .clear
        
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    func configure(title: String, isSelected: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .kern: -0.23,
            .foregroundColor: isSelected
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 1)
            : UIColor(red: 0.40392157, green: 0.40392157, blue: 0.40392157, alpha: 1)
        ]
        titleLabel.attributedText = NSAttributedString(string: title, attributes: attrs)
        
        contentView.backgroundColor = isSelected
        ? UIColor(red: 0.09019608, green: 0.09019608, blue: 0.09019608, alpha: 1)
        : .clear
    }
    
    static func width(for title: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .kern: -0.23
        ]
        
        let textW = ceil((title as NSString).size(withAttributes: attrs).width)
        
        return textW + 16 * 2
    }
}

// MARK: - Picker View

final class CameraModePickerView: UIView {
    
    // MARK: Constants
    
    private let itemSpacing: CGFloat = 0
    
    // MARK: State
    
    private var modes: [CameraMode]
    private var selectedIndex: Int = 0
    
    var onModeChanged: ((Int) -> Void)?
    
    // MARK: CollectionView
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.dataSource = self
        cv.delegate = self
        cv.register(CameraModeCell.self, forCellWithReuseIdentifier: CameraModeCell.reuseId)
        return cv
    }()
    
    // MARK: Init
    
    init(modes: [CameraMode]) {
        self.modes = modes
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    // MARK: Public
    
    func setSelectedIndex(_ index: Int, animated: Bool) {
        selectItem(at: index, animated: animated)
    }
    
    func setModes(_ new: [CameraMode]) {
        self.modes = new
        collectionView.reloadData()
        selectedIndex = min(selectedIndex, max(0, modes.count - 1))
        DispatchQueue.main.async { [weak self] in
            self?.centerItem(at: self?.selectedIndex ?? 0, animated: false)
        }
    }
    
    // MARK: Setup
    
    private func setup() {
        backgroundColor = .black
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard bounds.width > 0 else { return }
        
        let firstW = cellWidth(at: 0) ?? 0
        let lastW  = cellWidth(at: modes.count - 1) ?? firstW
        
        let leftInset  = max(0, (bounds.width - firstW) / 2)
        let rightInset = max(0, (bounds.width - lastW) / 2)
        
        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: leftInset,
            bottom: 0,
            right: rightInset
        )
    }
    
    // MARK: Selection
    
    private func selectItem(at index: Int, animated: Bool = true) {
        let clampedIndex = max(0, min(index, modes.count - 1))
        
        guard clampedIndex != selectedIndex else {
            centerItem(at: clampedIndex, animated: animated)
            return
        }
        
        selectedIndex = clampedIndex
        onModeChanged?(clampedIndex)
        
        collectionView.reloadData()
        centerItem(at: clampedIndex, animated: animated)
    }
    
    private func centerItem(at index: Int, animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(
            at: IndexPath(item: index, section: 0)
        ) else { return }
        
        let offsetX = attributes.center.x - collectionView.bounds.width / 2
        collectionView.setContentOffset(
            CGPoint(x: offsetX, y: 0),
            animated: animated
        )
    }
    
    // MARK: Snap Logic (dynamic width)
    
    private func snapAfterScroll() {
        let centerX = collectionView.contentOffset.x + collectionView.bounds.width / 2
        
        let visibleAttributes = collectionView.collectionViewLayout
            .layoutAttributesForElements(in: collectionView.bounds) ?? []
        
        guard let nearest = visibleAttributes.min(
            by: { abs($0.center.x - centerX) < abs($1.center.x - centerX) }
        ) else { return }
        
        let nearestIndex = nearest.indexPath.item
        let currentAttr = collectionView.layoutAttributesForItem(
            at: IndexPath(item: selectedIndex, section: 0)
        )
        
        let distance = nearest.center.x - (currentAttr?.center.x ?? nearest.center.x)
        let threshold: CGFloat = 30
        
        // сильный свайп → прыжок
        if abs(nearestIndex - selectedIndex) >= 1 {
            selectItem(at: nearestIndex)
            return
        }
        
        // слабый свайп → порог
        if distance > threshold {
            selectItem(at: selectedIndex + 1)
        } else if distance < -threshold {
            selectItem(at: selectedIndex - 1)
        } else {
            selectItem(at: selectedIndex)
        }
    }
    
    private func cellWidth(at index: Int) -> CGFloat? {
        guard index < modes.count else { return nil }
        return CameraModeCell.width(for: modes[index].title)
    }
}

// MARK: - CollectionView Delegates

extension CameraModePickerView: UICollectionViewDataSource,
                                UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        modes.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CameraModeCell.reuseId,
            for: indexPath
        ) as! CameraModeCell
        
        cell.configure(
            title: modes[indexPath.item].title,
            isSelected: indexPath.item == selectedIndex
        )
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        selectItem(at: indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = CameraModeCell.width(for: modes[indexPath.item].title)
        return CGSize(width: width, height: bounds.height)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapAfterScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                  willDecelerate decelerate: Bool) {
        if !decelerate {
            snapAfterScroll()
        }
    }
}
