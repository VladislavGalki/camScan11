import SwiftUI

struct OpenDocumentSignatureOverlayView: View {
    let items: [DocumentSignatureItem]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(items) { item in
                    signatureBlock(item, in: geo.size)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func signatureBlock(_ item: DocumentSignatureItem, in size: CGSize) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height

        return Group {
            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: width, height: height)
        .opacity(item.opacity)
        .rotationEffect(.degrees(item.rotation))
    }
}
