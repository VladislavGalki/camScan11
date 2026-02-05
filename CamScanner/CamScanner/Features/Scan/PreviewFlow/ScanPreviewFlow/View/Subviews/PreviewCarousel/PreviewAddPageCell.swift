import UIKit

final class PreviewAddPageCell: UICollectionViewCell {

    static let reuseId = "PreviewAddPageCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 0

        setupUI()
        setupShadow()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center

        let icon = UIImageView(image: UIImage(named: "add_circle"))
        icon.contentMode = .scaleAspectFit

        configureLabel()

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)

        contentView.addSubview(stack)

        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    private func configureLabel() {
        let text = "Add Page"
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        paragraph.alignment = .center

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .kern: -0.43,
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor(
                    red: 0/255,
                    green: 136/255,
                    blue: 255/255,
                    alpha: 1
                )
            ]
        )

        label.attributedText = attributed
        label.numberOfLines = 1
    }

    private func setupShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }
}
