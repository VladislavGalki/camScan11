import SwiftUI

struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let urls: [URL]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )

        vc.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }

        return vc
    }

    func updateUIViewController(_: UIActivityViewController, context: Context) {}
}
