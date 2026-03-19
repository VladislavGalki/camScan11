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
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
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

        print("""
        🟪 MAKE UI TEXT VIEW
        inputText: \(text)
        inputCount: \(text.count)
        attributedLength: \(textView.attributedText?.length ?? 0)
        bounds: \(textView.bounds)
        textContainerInset: \(textView.textContainerInset)
        typingAttributes: \(textView.typingAttributes)
        """)

        DispatchQueue.main.async {
            textView.becomeFirstResponder()
            self.performFullReflow(on: textView)

            print("""
            🟪 MAKE UI TEXT VIEW AFTER LAYOUT
            text: \(textView.text)
            contentSize: \(textView.contentSize)
            bounds: \(textView.bounds)
            textContainer.size: \(textView.textContainer.size)
            selectedRange: \(textView.selectedRange)
            """)

            DispatchQueue.main.async {
                self.performFullReflow(on: textView)

                print("""
                🟪 MAKE UI TEXT VIEW AFTER SECOND LAYOUT
                text: \(textView.text)
                contentSize: \(textView.contentSize)
                bounds: \(textView.bounds)
                textContainer.size: \(textView.textContainer.size)
                selectedRange: \(textView.selectedRange)
                """)
            }
        }

        return container
    }

    func updateUIView(_ uiView: TextViewContainer, context: Context) {
        let textView = uiView.textView

        print("""
        🟪 UPDATE UI TEXT VIEW BEFORE
        bindingText: \(text)
        bindingCount: \(text.count)
        textView.text: \(textView.text)
        textViewCount: \(textView.text.count)
        isFocused: \(textView.isFirstResponder)
        bounds: \(textView.bounds)
        contentSize: \(textView.contentSize)
        textContainer.size(before): \(textView.textContainer.size)
        """)

        textView.textAlignment = textAlignment
        textView.textColor = textColor
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes = typingAttributes
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        textView.textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )

        let isFocused = textView.isFirstResponder
        if !isFocused && textView.text != text {
            textView.attributedText = attributedString(for: text)
        }

        performFullReflow(on: textView)

        print("""
        🟪 UPDATE UI TEXT VIEW AFTER
        textView.text: \(textView.text)
        textViewCount: \(textView.text.count)
        attributedLength: \(textView.attributedText?.length ?? 0)
        bounds: \(textView.bounds)
        contentSize: \(textView.contentSize)
        textContainer.size(after): \(textView.textContainer.size)
        selectedRange: \(textView.selectedRange)
        """)
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
        NSAttributedString(
            string: text,
            attributes: typingAttributes
        )
    }

    private func performFullReflow(on textView: UITextView) {
        let availableTextWidth = max(textView.bounds.width - horizontalInset * 2, 1)

        textView.textContainer.size = CGSize(
            width: availableTextWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        let fullRange = NSRange(location: 0, length: textView.textStorage.length)
        textView.layoutManager.invalidateLayout(
            forCharacterRange: fullRange,
            actualCharacterRange: nil
        )
        textView.layoutManager.ensureLayout(for: textView.textContainer)

        textView.setNeedsDisplay()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        textView.setContentOffset(.zero, animated: false)
        textView.scrollRangeToVisible(textView.selectedRange)
    }

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

            DispatchQueue.main.async {
                self.parent.performFullReflow(on: textView)

                print("""
                🟧 DID CHANGE
                text: \(textView.text)
                count: \(textView.text.count)
                selectedRange: \(textView.selectedRange)
                bounds: \(textView.bounds)
                contentSize: \(textView.contentSize)
                textContainer.size: \(textView.textContainer.size)
                """)
            }
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

            guard let stringRange = Range(range, in: textView.text) else {
                return true
            }

            let predictedText = textView.text.replacingCharacters(in: stringRange, with: replacement)
            parent.onPredictedTextChange?(predictedText)

            print("""
            🟥 SHOULD CHANGE
            current: \(textView.text)
            replacement: \(replacement)
            range: \(range)
            predicted: \(predictedText)
            selectedRange(before): \(textView.selectedRange)
            bounds: \(textView.bounds)
            contentSize: \(textView.contentSize)
            """)

            return true
        }
    }
}

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

    required init?(coder: NSCoder) {
        fatalError()
    }
}
