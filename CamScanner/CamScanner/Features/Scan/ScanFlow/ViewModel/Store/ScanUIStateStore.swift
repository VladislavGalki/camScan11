import Foundation
import SwiftUI

final class ScanUIStateStore: ObservableObject {
    @Published var flashMode: FlashMode = .auto
    @Published var quality: QualityPreset = .hd

    @Published var selectedDocumentType: DocumentTypeEnum = .documents
    @Published var idFrameRectInCameraSpace: CGRect = .zero

    @Published var idCaptureSide: IdCaptureSide = .front
    
    func toggleFlashMode() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        }
    }
}
