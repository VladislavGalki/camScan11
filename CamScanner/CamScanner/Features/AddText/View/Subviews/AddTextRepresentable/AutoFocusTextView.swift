import SwiftUI
import UIKit

struct AutoFocusTextView: UIViewRepresentable {
    @Binding var text: String

    let fontSize: CGFloat
    let textColor: UIColor
    let textAlignment: NSTextAlignment
    let onSubmit: () -> Void

    private let horizontalInset: CGFloat = 8
    private let verticalInset: CGFloat = 9
    private let kern: CGFloat = -0.43

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()

        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.clipsToBounds = true

        view.textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.lineBreakMode = .byWordWrapping
        view.textContainer.widthTracksTextView = true
        view.textContainer.maximumNumberOfLines = 0

        view.returnKeyType = .done
        view.typingAttributes = typingAttributes
        view.attributedText = attributedString(for: text)
        view.textAlignment = textAlignment

        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }

        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.attributedText = attributedString(for: text)
        }

        uiView.textAlignment = textAlignment
        uiView.textColor = textColor
        uiView.font = .systemFont(ofSize: fontSize, weight: .regular)
        uiView.typingAttributes = typingAttributes
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        uiView.resignFirstResponder()
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

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: AutoFocusTextView

        init(_ parent: AutoFocusTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
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

            return true
        }
    }
}
