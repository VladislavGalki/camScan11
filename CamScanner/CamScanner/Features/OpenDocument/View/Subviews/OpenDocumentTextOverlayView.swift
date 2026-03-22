import SwiftUI

struct OpenDocumentTextOverlayView: View {
    let items: [DocumentTextItem]

    /// Reference cell width for font scaling. When 0, uses geo.size (no scaling).
    /// Pass the original cell width (e.g. 322) when displaying in a smaller preview.
    var referenceWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let fontScale = referenceWidth > 0 ? geo.size.width / referenceWidth : 1.0

            ZStack {
                ForEach(items) { item in
                    textBlock(item, in: geo.size, fontScale: fontScale)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
            .onAppear {
                print("📝 TextOverlay | geo.size=\(geo.size) items=\(items.count) fontScale=\(fontScale)")
                for item in items {
                    let posX = item.centerX * geo.size.width
                    let posY = item.centerY * geo.size.height
                    let w = item.width * geo.size.width
                    let h = item.height * geo.size.height
                    print("📝 TextOverlay |   \"\(item.text)\" center=(\(item.centerX), \(item.centerY)) pos=(\(posX), \(posY)) blockSize=(\(w), \(h)) fontSize=\(item.style.fontSize) rot=\(item.rotation)")
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func textBlock(_ item: DocumentTextItem, in size: CGSize, fontScale: CGFloat) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height
        let scaledPadding = 8 * fontScale

        return Text(item.text)
            .font(.system(size: item.style.fontSize * fontScale, weight: .regular))
            .kerning(item.style.letterSpacing * fontScale)
            .lineSpacing(0)
            .foregroundStyle(Color(rgbaHex: item.style.textColorHex) ?? .black)
            .multilineTextAlignment(textAlignment(for: item.style.alignment))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: max(width - scaledPadding * 2, 0),
                height: max(height - scaledPadding * 2, 0),
                alignment: .leading
            )
            .padding(.horizontal, scaledPadding)
            .padding(.vertical, scaledPadding)
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
            .rotationEffect(.degrees(item.rotation))
    }

    private func textAlignment(for alignment: DocumentTextAlignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
