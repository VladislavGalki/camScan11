import UIKit

enum TextMeasurer {
    struct Insets {
        let horizontal: CGFloat
        let vertical: CGFloat

        static let standard = Insets(horizontal: 8, vertical: 8)
    }

    static let defaultKern: CGFloat = -0.43

    static func measure(
        text: String,
        fontSize: CGFloat,
        kern: CGFloat = defaultKern,
        maxWidth: CGFloat,
        insets: Insets = .standard
    ) -> CGSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .kern: kern,
            .paragraphStyle: paragraph
        ]

        let sourceText = text.isEmpty ? " " : text
        let attributed = NSAttributedString(string: sourceText, attributes: attributes)

        let singleLineRect = attributed.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let contentIdealWidth = ceil(singleLineRect.width)
        let availableContentWidth = max(maxWidth - insets.horizontal * 2, 1)
        let targetContentWidth = min(contentIdealWidth, availableContentWidth)

        let wrappedRect = attributed.boundingRect(
            with: CGSize(width: targetContentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return CGSize(
            width: targetContentWidth + insets.horizontal * 2,
            height: ceil(wrappedRect.height) + insets.vertical * 2
        )
    }

    static func measureHeight(
        text: String,
        fontSize: CGFloat,
        kern: CGFloat = defaultKern,
        availableWidth: CGFloat,
        insets: Insets = .standard
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .kern: kern,
            .paragraphStyle: paragraph
        ]

        let sourceText = text.isEmpty ? " " : text
        let attributed = NSAttributedString(string: sourceText, attributes: attributes)

        let textWidth = max(availableWidth - insets.horizontal * 2, 1)

        let wrappedRect = attributed.boundingRect(
            with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return ceil(wrappedRect.height) + insets.vertical * 2
    }
}
