import UIKit

enum TableRecognizerError: Error {
    case emptyImage
    case noText
    case visionFailure(Error)
}

protocol TableRecognizer {
    func recognizeTable(in image: UIImage) async throws -> RecognizedTable
}
