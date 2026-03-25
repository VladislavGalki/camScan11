import SwiftUI

struct OpenDocumentCombinedOverlayView: View {
    let textItems: [DocumentTextItem]
    let watermarkItems: [DocumentWatermarkItem]

    var referenceWidth: CGFloat = 0

    var body: some View {
        ZStack {
            OpenDocumentTextOverlayView(items: textItems, referenceWidth: referenceWidth)
            OpenDocumentWatermarkOverlayView(items: watermarkItems, referenceWidth: referenceWidth)
        }
        .allowsHitTesting(false)
    }
}
