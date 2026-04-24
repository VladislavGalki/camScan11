import UIKit

protocol DocumentTextRecognizer {
    /// Возвращает массив параграфов (каждый элемент — абзац, готовый для отдельного <w:p>).
    func recognizeParagraphs(in image: UIImage) async throws -> [String]
}
