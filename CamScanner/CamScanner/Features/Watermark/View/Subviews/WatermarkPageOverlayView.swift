import SwiftUI

// MARK: - Session Models

private struct MoveSession: Equatable {
    let watermarkID: UUID
    let initialCenterX: CGFloat
    let initialCenterY: CGFloat
}

// MARK: - View

struct WatermarkPageOverlayView: View {
    private enum Constants {
        static let borderWidth: CGFloat = 2
    }

    // MARK: - State

    @State private var moveSession: MoveSession?

    // MARK: - Input

    let pageIndex: Int
    let items: [DocumentWatermarkItem]
    let selectedWatermarkID: UUID?
    let editingWatermarkID: UUID?
    let editingTextDraft: String
    weak var delegate: WatermarkPageDelegate?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                pageTapLayer(in: geo.size)

                ForEach(items) { item in
                    draggableWatermarkBlock(item, in: geo.size)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
            .onAppear { delegate?.didChangePageSize(geo.size) }
            .onChange(of: geo.size) { _, newSize in
                delegate?.didChangePageSize(newSize)
            }
        }
    }
}

// MARK: - Tap Layer

private extension WatermarkPageOverlayView {
    func pageTapLayer(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedItem = hitTestItem(at: value.location, in: size) {
                            delegate?.didTapWatermark(id: tappedItem.id)
                        } else {
                            let normalizedLocation = normalize(value.location, in: size)
                            let measured = TextMeasurer.measure(
                                text: "Watermark",
                                fontSize: DocumentWatermarkStyle.default.fontSize,
                                maxWidth: size.width
                            )
                            let initialSize = CGSize(
                                width: measured.width / max(size.width, 1),
                                height: measured.height / max(size.height, 1)
                            )
                            delegate?.didTapPage(index: pageIndex, location: normalizedLocation, initialSize: initialSize)
                        }
                    }
            )
    }
}

// MARK: - Watermark Block

private extension WatermarkPageOverlayView {
    func draggableWatermarkBlock(_ item: DocumentWatermarkItem, in size: CGSize) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height
        let isSelected = item.id == selectedWatermarkID
        let isEditing = item.id == editingWatermarkID

        return ZStack {
            ZStack {
                selectionBorder(isVisible: isSelected || isEditing, width: width, height: height)

                if isEditing {
                    editingContent(item, width: width, height: height, pageSize: size)
                } else {
                    textContent(item, width: width, height: height)
                        .frame(width: width, height: height, alignment: .leading)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(for: item, in: size))
                        .highPriorityGesture(
                            TapGesture().onEnded { delegate?.didTapWatermark(id: item.id) }
                        )
                }
            }
            .rotationEffect(.degrees(item.rotation))
        }
        .frame(width: width, height: height)
    }

    func editingContent(_ item: DocumentWatermarkItem, width: CGFloat, height: CGFloat, pageSize: CGSize) -> some View {
        AutoFocusTextView(
            text: Binding(
                get: { editingTextDraft },
                set: { delegate?.didChangeEditingText($0, pageSize: pageSize) }
            ),
            fontSize: item.style.fontSize,
            textColor: UIColor(rgbaHex: item.style.textColorHex) ?? .black,
            textAlignment: item.style.alignment.wmNSTextAlignment,
            onPredictedTextChange: { delegate?.didChangeEditingText($0, pageSize: pageSize) },
            onSubmit: { delegate?.didSubmitEditing() }
        )
        .frame(width: width, height: height)
        .clipped()
    }

    func selectionBorder(isVisible: Bool, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .stroke(isVisible ? .bg(.accent) : .clear, lineWidth: Constants.borderWidth)
            .frame(width: width, height: height)
    }

    func textContent(_ item: DocumentWatermarkItem, width: CGFloat, height: CGFloat) -> some View {
        Text(item.text)
            .font(.system(size: item.style.fontSize, weight: .regular))
            .kerning(item.style.letterSpacing)
            .lineSpacing(0)
            .foregroundStyle(Color(rgbaHex: item.style.textColorHex) ?? .black)
            .multilineTextAlignment(item.style.alignment.wmTextAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
            .opacity(item.opacity)
    }
}

// MARK: - Move Gesture

private extension WatermarkPageOverlayView {
    func moveGesture(for item: DocumentWatermarkItem, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if moveSession?.watermarkID != item.id {
                    moveSession = MoveSession(
                        watermarkID: item.id,
                        initialCenterX: item.centerX,
                        initialCenterY: item.centerY
                    )
                }

                guard let session = moveSession else { return }

                let deltaX = value.translation.width / max(size.width, 1)
                let deltaY = value.translation.height / max(size.height, 1)

                delegate?.didMoveWatermark(
                    id: item.id,
                    to: CGPoint(x: session.initialCenterX + deltaX, y: session.initialCenterY + deltaY)
                )
            }
            .onEnded { _ in moveSession = nil }
    }
}

// MARK: - Hit Testing

private extension WatermarkPageOverlayView {
    func hitTestItem(at location: CGPoint, in size: CGSize) -> DocumentWatermarkItem? {
        items.reversed().first { item in
            let width = item.width * size.width
            let height = item.height * size.height
            let rect = CGRect(
                x: item.centerX * size.width - width / 2,
                y: item.centerY * size.height - height / 2,
                width: width,
                height: height
            )
            return rect.contains(location)
        }
    }

    func normalize(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x / max(size.width, 1), 0), 1),
            y: min(max(location.y / max(size.height, 1), 0), 1)
        )
    }
}

// MARK: - Alignment Helpers

private extension DocumentTextAlignment {
    var wmTextAlignment: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    var wmNSTextAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
