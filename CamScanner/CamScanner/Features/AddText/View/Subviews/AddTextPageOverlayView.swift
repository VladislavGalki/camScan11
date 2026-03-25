import SwiftUI

// MARK: - Session Models

private struct MoveSession: Equatable {
    let textID: UUID
    let initialCenterX: CGFloat
    let initialCenterY: CGFloat
}

private struct ResizeSession: Equatable {
    let textID: UUID
    let side: ResizeSide
    let initialWidth: CGFloat
    let initialCenterX: CGFloat
    let startLocationX: CGFloat
}

private enum ResizeSide {
    case left, right
}

private struct ActiveResize: Equatable {
    let textID: UUID
    var width: CGFloat
    var height: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat
}

// MARK: - View

struct AddTextPageOverlayView: View {
    private enum Constants {
        static let initialWidth: CGFloat = 56
        static let initialHeight: CGFloat = 44
        static let handleTouchSize: CGFloat = 44
        static let handleVisualSize: CGFloat = 12
        static let borderWidth: CGFloat = 2
    }

    // MARK: - State

    @State private var moveSession: MoveSession?
    @State private var resizeSession: ResizeSession?
    @State private var activeResize: ActiveResize?

    // MARK: - Input

    let pageIndex: Int
    let items: [DocumentTextItem]
    let selectedTextID: UUID?
    let editingTextID: UUID?
    let editingTextDraft: String
    weak var delegate: AddTextPageDelegate?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                pageTapLayer(in: geo.size)

                ForEach(items) { item in
                    draggableTextBlock(item, in: geo.size)
                        .position(
                            x: displayedCenterX(for: item) * geo.size.width,
                            y: displayedCenterY(for: item) * geo.size.height
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

private extension AddTextPageOverlayView {
    func pageTapLayer(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedItem = hitTestItem(at: value.location, in: size) {
                            delegate?.didTapText(id: tappedItem.id)
                        } else {
                            let normalizedLocation = normalize(value.location, in: size)
                            let initialSize = CGSize(
                                width: Constants.initialWidth / max(size.width, 1),
                                height: Constants.initialHeight / max(size.height, 1)
                            )
                            delegate?.didTapPage(index: pageIndex, location: normalizedLocation, initialSize: initialSize)
                        }
                    }
            )
    }
}

// MARK: - Text Block

private extension AddTextPageOverlayView {
    func draggableTextBlock(_ item: DocumentTextItem, in size: CGSize) -> some View {
        let width = displayedWidth(for: item) * size.width
        let height = displayedHeight(for: item) * size.height
        let isSelected = item.id == selectedTextID
        let isEditing = item.id == editingTextID

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
                            TapGesture().onEnded { delegate?.didTapText(id: item.id) }
                        )
                }

                if isSelected && !isEditing {
                    resizeHandle(item, side: .left, in: size, width: width, height: height)
                    resizeHandle(item, side: .right, in: size, width: width, height: height)
                }
            }
            .rotationEffect(.degrees(item.rotation))
        }
        .frame(width: width, height: height)
    }

    func editingContent(_ item: DocumentTextItem, width: CGFloat, height: CGFloat, pageSize: CGSize) -> some View {
        AutoFocusTextView(
            text: Binding(
                get: { editingTextDraft },
                set: { delegate?.didChangeEditingText($0, pageSize: pageSize) }
            ),
            fontSize: item.style.fontSize,
            textColor: UIColor(rgbaHex: item.style.textColorHex) ?? .black,
            textAlignment: item.style.alignment.nsTextAlignment,
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

    func textContent(_ item: DocumentTextItem, width: CGFloat, height: CGFloat) -> some View {
        Text(item.text)
            .font(.system(size: item.style.fontSize, weight: .regular))
            .kerning(item.style.letterSpacing)
            .lineSpacing(0)
            .foregroundStyle(Color(rgbaHex: item.style.textColorHex) ?? .black)
            .multilineTextAlignment(item.style.alignment.textAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: max(width - 16, 0), height: max(height - 16, 0), alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
    }
}

// MARK: - Move Gesture

private extension AddTextPageOverlayView {
    func moveGesture(for item: DocumentTextItem, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if moveSession?.textID != item.id {
                    moveSession = MoveSession(
                        textID: item.id,
                        initialCenterX: item.centerX,
                        initialCenterY: item.centerY
                    )
                }

                guard let session = moveSession else { return }

                let deltaX = value.translation.width / max(size.width, 1)
                let deltaY = value.translation.height / max(size.height, 1)

                delegate?.didMoveText(
                    id: item.id,
                    to: CGPoint(x: session.initialCenterX + deltaX, y: session.initialCenterY + deltaY)
                )
            }
            .onEnded { _ in moveSession = nil }
    }
}

// MARK: - Resize

private extension AddTextPageOverlayView {
    func resizeHandle(_ item: DocumentTextItem, side: ResizeSide, in size: CGSize, width: CGFloat, height: CGFloat) -> some View {
        resizeHandleVisual
            .position(x: side == .left ? 0 : width, y: height / 2)
            .highPriorityGesture(resizeGesture(for: item, side: side, in: size))
    }

    func resizeGesture(for item: DocumentTextItem, side: ResizeSide, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if resizeSession?.textID != item.id || resizeSession?.side != side {
                    resizeSession = ResizeSession(
                        textID: item.id,
                        side: side,
                        initialWidth: item.width,
                        initialCenterX: item.centerX,
                        startLocationX: value.startLocation.x
                    )
                    delegate?.didChangeResizeState(isResizing: true)
                }

                guard let session = resizeSession else { return }

                let deltaXNorm = (value.location.x - session.startLocationX) / max(size.width, 1)
                let minWidthNorm = Constants.initialWidth / max(size.width, 1)

                let clampedWidth: CGFloat
                let newCenterX: CGFloat

                switch side {
                case .left:
                    let rightEdge = session.initialCenterX + session.initialWidth / 2
                    let proposed = session.initialWidth - deltaXNorm
                    clampedWidth = max(minWidthNorm, min(proposed, rightEdge))
                    newCenterX = rightEdge - clampedWidth / 2

                case .right:
                    let leftEdge = session.initialCenterX - session.initialWidth / 2
                    let proposed = session.initialWidth + deltaXNorm
                    let maxWidth = 1 - leftEdge
                    clampedWidth = max(minWidthNorm, min(proposed, maxWidth))
                    newCenterX = leftEdge + clampedWidth / 2
                }

                let previewHeight = previewMeasuredHeight(for: item, widthNorm: clampedWidth, pageSize: size)
                let topEdgeY = item.centerY - item.height / 2

                activeResize = ActiveResize(
                    textID: item.id,
                    width: clampedWidth,
                    height: previewHeight,
                    centerX: newCenterX,
                    centerY: topEdgeY + previewHeight / 2
                )
            }
            .onEnded { _ in
                delegate?.didChangeResizeState(isResizing: false)
                finishResize(for: item, pageSize: size)
            }
    }

    func finishResize(for item: DocumentTextItem, pageSize: CGSize) {
        guard let session = resizeSession else { return }

        let finalWidth = activeResize?.width ?? session.initialWidth
        let finalCenterX = activeResize?.centerX ?? session.initialCenterX

        delegate?.didResizeText(id: item.id, width: finalWidth, centerX: finalCenterX, pageSize: pageSize)

        resizeSession = nil
        activeResize = nil
    }

    var resizeHandleVisual: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: Constants.handleTouchSize, height: Constants.handleTouchSize)

            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)

            Circle()
                .stroke(.bg(.accent), lineWidth: 4)
                .frame(width: Constants.handleVisualSize, height: Constants.handleVisualSize)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Display Helpers

private extension AddTextPageOverlayView {
    func displayedWidth(for item: DocumentTextItem) -> CGFloat {
        activeResize?.textID == item.id ? (activeResize?.width ?? item.width) : item.width
    }

    func displayedHeight(for item: DocumentTextItem) -> CGFloat {
        activeResize?.textID == item.id ? (activeResize?.height ?? item.height) : item.height
    }

    func displayedCenterX(for item: DocumentTextItem) -> CGFloat {
        activeResize?.textID == item.id ? (activeResize?.centerX ?? item.centerX) : item.centerX
    }

    func displayedCenterY(for item: DocumentTextItem) -> CGFloat {
        activeResize?.textID == item.id ? (activeResize?.centerY ?? item.centerY) : item.centerY
    }

    func previewMeasuredHeight(for item: DocumentTextItem, widthNorm: CGFloat, pageSize: CGSize) -> CGFloat {
        let minHeightPt: CGFloat = 44
        let widthPt = widthNorm * max(pageSize.width, 1)

        let measuredHeight = TextMeasurer.measureHeight(
            text: item.text,
            fontSize: item.style.fontSize,
            kern: item.style.letterSpacing,
            availableWidth: widthPt
        )

        let heightPt = max(measuredHeight, minHeightPt)
        return heightPt / max(pageSize.height, 1)
    }
}

// MARK: - Hit Testing

private extension AddTextPageOverlayView {
    func hitTestItem(at location: CGPoint, in size: CGSize) -> DocumentTextItem? {
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
    var textAlignment: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
