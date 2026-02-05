import UIKit

final class PaddedLabel: UILabel {

    // MARK: Layout

    var contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {

        font = .systemFont(ofSize: 15, weight: .regular)
        textColor = .white

        if let text {
            attributedText = NSAttributedString(
                string: text,
                attributes: [.kern: -0.23]
            )
        }

        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        clipsToBounds = true
        textAlignment = .center
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    // MARK: Override text setter to keep tracking

    override var text: String? {
        didSet {
            guard let text else { return }

            attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                    .foregroundColor: UIColor.white,
                    .kern: -0.23
                ]
            )
        }
    }
}
