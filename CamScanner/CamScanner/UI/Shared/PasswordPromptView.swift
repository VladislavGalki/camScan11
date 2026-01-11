import UIKit

final class PasswordPromptView {
    
    static let shared = PasswordPromptView()
    
    private init() {}

    func present(
        title: String,
        message: String?,
        onDone: @escaping (String) -> Void,
        onRemove: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        guard let vc = UIViewController.topMost() else { return }

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.isSecureTextEntry = true
            tf.placeholder = "Пароль (до 6 символов)"
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none

            tf.addAction(.init(handler: { _ in
                if let text = tf.text, text.count > 6 {
                    tf.text = String(text.prefix(6))
                }
            }), for: .editingChanged)
        }

        alert.addAction(.init(title: "Отмена", style: .cancel) { _ in
            onCancel?()
        })

        alert.addAction(.init(title: "OK", style: .default) { _ in
            let password = alert.textFields?.first?.text ?? ""
            onDone(password)
        })
        
        alert.addAction(.init(title: "Удалить пароль", style: .default) { _ in
            let password = alert.textFields?.first?.text ?? ""
            onRemove?(password)
        })

        vc.present(alert, animated: true)
    }
}
