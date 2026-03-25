import SwiftUI

struct OpenDocumentWatermarkOverlayView: View {
    let items: [DocumentWatermarkItem]

    var referenceWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let fontScale = referenceWidth > 0 ? geo.size.width / referenceWidth : 1.0

            ZStack {
                ForEach(items) { item in
                    watermarkBlock(item, in: geo.size, fontScale: fontScale)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func watermarkBlock(_ item: DocumentWatermarkItem, in size: CGSize, fontScale: CGFloat) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height
        let scaledPadding = 8 * fontScale

        return Text(item.text)
            .font(.system(size: item.style.fontSize * fontScale, weight: .regular))
            .kerning(item.style.letterSpacing * fontScale)
            .lineSpacing(0)
            .foregroundStyle(Color(rgbaHex: item.style.textColorHex) ?? .black)
            .multilineTextAlignment(watermarkTextAlignment(for: item.style.alignment))
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
            .opacity(item.opacity)
            .rotationEffect(.degrees(item.rotation))
    }

    private func watermarkTextAlignment(for alignment: DocumentTextAlignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
