import SwiftUI

struct OpenDocumentTextOverlayView: View {
    let items: [DocumentTextItem]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(items) { item in
                    textBlock(item, in: geo.size)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
            .onAppear {
                print("📝 TextOverlay | geo.size=\(geo.size) items=\(items.count)")
                for item in items {
                    let posX = item.centerX * geo.size.width
                    let posY = item.centerY * geo.size.height
                    let w = item.width * geo.size.width
                    let h = item.height * geo.size.height
                    print("📝 TextOverlay |   \"\(item.text)\" pos=(\(posX), \(posY)) blockSize=(\(w), \(h)) fontSize=\(item.style.fontSize)")
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func textBlock(_ item: DocumentTextItem, in size: CGSize) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height

        return Text(item.text)
            .font(.system(size: item.style.fontSize, weight: .regular))
            .kerning(item.style.letterSpacing)
            .lineSpacing(0)
            .foregroundStyle(Color(rgbaHex: item.style.textColorHex) ?? .black)
            .multilineTextAlignment(textAlignment(for: item.style.alignment))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: max(width - 16, 0),
                height: max(height - 16, 0),
                alignment: .leading
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
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
