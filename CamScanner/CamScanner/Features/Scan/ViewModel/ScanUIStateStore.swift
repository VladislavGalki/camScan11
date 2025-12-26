import Foundation
import SwiftUI

/// UI selections / state, который не обязан быть в ViewModel.
/// Это то, чем управляет UI (панели, пикеры, выбранные режимы).
final class ScanUIStateStore: ObservableObject {

    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single
    @Published var selectedDocumentType: DocumentType = .scan
}
