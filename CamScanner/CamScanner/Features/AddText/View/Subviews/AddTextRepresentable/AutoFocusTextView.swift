import SwiftUI
import UIKit

struct AutoFocusTextView: UIViewRepresentable {
    @Binding var text: String

    let fontSize: CGFloat
    let textColor: UIColor
    let textAlignment: NSTextAlignment
    let onPredictedTextChange: ((String) -> Void)?
    let onSubmit: () -> Void

    private let horizontalInset: CGFloat = 8
    private let verticalInset: CGFloat = 8
    private let kern: CGFloat = -0.43

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TextViewContainer {
        let container = TextViewContainer()
        let textView = container.textView

        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.clipsToBounds = true
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero

        textView.textContainerInset = UIEdgeInsets(
            top: verticalInset, left: horizontalInset,
            bottom: verticalInset, right: horizontalInset
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.maximumNumberOfLines = 0

        textView.returnKeyType = .done
        textView.typingAttributes = typingAttributes
        textView.attributedText = attributedString(for: text)
        textView.textAlignment = textAlignment

        DispatchQueue.main.async {
            textView.becomeFirstResponder()
            self.performFullReflow(on: textView)
        }

        return container
    }

    func updateUIView(_ uiView: TextViewContainer, context: Context) {
        let textView = uiView.textView

        textView.textAlignment = textAlignment
        textView.textColor = textColor
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes = typingAttributes
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        textView.textContainerInset = UIEdgeInsets(
            top: verticalInset, left: horizontalInset,
            bottom: verticalInset, right: horizontalInset
        )

        if !textView.isFirstResponder && textView.text != text {
            textView.attributedText = attributedString(for: text)
        }

        performFullReflow(on: textView)
    }

    static func dismantleUIView(_ uiView: TextViewContainer, coordinator: Coordinator) {
        uiView.textView.resignFirstResponder()
    }

    private var typingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: textColor,
            .kern: kern
        ]
    }

    private func attributedString(for text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: typingAttributes)
    }

    private func performFullReflow(on textView: UITextView) {
        let availableTextWidth = max(textView.bounds.width - horizontalInset * 2, 1)

        textView.textContainer.size = CGSize(
            width: availableTextWidth,
            height: .greatestFiniteMagnitude
        )

        let fullRange = NSRange(location: 0, length: textView.textStorage.length)
        textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        textView.layoutManager.ensureLayout(for: textView.textContainer)

        textView.setNeedsDisplay()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        textView.setContentOffset(.zero, animated: false)
        textView.scrollRangeToVisible(textView.selectedRange)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: AutoFocusTextView

        init(_ parent: AutoFocusTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
            parent.performFullReflow(on: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            if replacement == "\n" {
                parent.onSubmit()
                return false
            }

            if let stringRange = Range(range, in: textView.text) {
                let predictedText = textView.text.replacingCharacters(in: stringRange, with: replacement)
                parent.onPredictedTextChange?(predictedText)
            }

            return true
        }
    }
}

// MARK: - TextViewContainer

final class TextViewContainer: UIView {
    let textView = UITextView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        backgroundColor = .clear

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
