import SwiftUI
import UIKit

struct DocumentExporterSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let saveToPhotos = SaveToPhotosActivity()
        let vc = UIActivityViewController(activityItems: items, applicationActivities: [saveToPhotos])
        vc.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
