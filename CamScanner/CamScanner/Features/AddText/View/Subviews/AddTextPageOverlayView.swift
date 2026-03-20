import SwiftUI

// MARK: - Resize Models

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
    case left
    case right
}

// MARK: - View

struct AddTextPageOverlayView: View {
    // MARK: Constants

    private enum Constants {
        static let initialWidth: CGFloat = 56
        static let initialHeight: CGFloat = 44

        static let handleTouchSize = CGSize(width: 44, height: 44)
        static let handleVisualSize: CGFloat = 12
        static let borderWidth: CGFloat = 2
    }

    // MARK: State

    @State private var moveSession: MoveSession?
    @State private var activeResizeTextID: UUID?
    @State private var activeResizeWidth: CGFloat?
    @State private var activeResizeHeight: CGFloat?
    @State private var activeResizeCenterX: CGFloat?
    @State private var activeResizeCenterY: CGFloat?
    @State private var resizeSession: ResizeSession?

    // MARK: Input

    let pageIndex: Int
    let items: [DocumentTextItem]
    let selectedTextID: UUID?
    let editingTextID: UUID?
    let editingTextDraft: String

    let onPageTap: (CGPoint, CGSize) -> Void
    let onTextTap: (UUID) -> Void
    let onTextMove: (UUID, CGPoint) -> Void
    let onTextResize: (UUID, CGFloat, CGFloat?, CGSize) -> Void
    let onPageSizeChanged: (CGSize) -> Void
    let onResizeStateChanged: (Bool) -> Void
    
    let onEditingTextChanged: (String, CGSize) -> Void
    let onEditingSubmit: () -> Void
    
    // MARK: Body

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
            .onAppear {
                onPageSizeChanged(geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                onPageSizeChanged(newSize)
            }
        }
    }
}

// MARK: - Layers

private extension AddTextPageOverlayView {
    func pageTapLayer(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let normalizedLocation = normalize(location: value.location, in: size)

                        if let tappedItem = hitTestItem(at: value.location, in: size) {
                            onTextTap(tappedItem.id)
                        } else {
                            let initialSize = CGSize(
                                width: Constants.initialWidth / max(size.width, 1),
                                height: Constants.initialHeight / max(size.height, 1)
                            )

                            onPageTap(normalizedLocation, initialSize)
                        }
                    }
            )
    }
}

// MARK: - Text Block

private extension AddTextPageOverlayView {
    private func draggableTextBlock(_ item: DocumentTextItem, in size: CGSize) -> some View {
        let width = displayedWidth(for: item) * size.width
        let height = displayedHeight(for: item) * size.height
        let isSelected = item.id == selectedTextID
        let isEditing = item.id == editingTextID

        return ZStack {
            ZStack {
                selectionBorder(
                    isSelected: isSelected || isEditing,
                    width: width,
                    height: height
                )

                if isEditing {
                    editingContent(item, width: width, height: height, pageSize: size)
                } else {
                    textContent(item, width: width, height: height)
                        .frame(width: width, height: height, alignment: .leading)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(for: item, in: size))
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded {
                                    onTextTap(item.id)
                                }
                        )
                }

                if isSelected && !isEditing {
                    leftResizeHandle(item, in: size, width: width, height: height)
                    rightResizeHandle(item, in: size, width: width, height: height)
                }
            }
            .rotationEffect(.degrees(item.rotation))
        }
        .frame(width: width, height: height)
    }
    
    private func editingContent(
        _ item: DocumentTextItem,
        width: CGFloat,
        height: CGFloat,
        pageSize: CGSize
    ) -> some View {
        print("""
        🟨 EDIT CONTENT
        item.id: \(item.id)
        item.text: \(item.text)
        editingTextDraft: \(editingTextDraft)
        width: \(width)
        height: \(height)
        pageSize: \(pageSize)
        isEditing: \(editingTextID == item.id)
        """)
        
        return AutoFocusTextView(
            text: Binding(
                get: { editingTextDraft },
                set: { newValue in
                    onEditingTextChanged(newValue, pageSize)
                }
            ),
            fontSize: item.style.fontSize,
            textColor: UIColor(rgbaHex: item.style.textColorHex) ?? .black,
            textAlignment: uiTextAlignment(for: item.style.alignment),
            onPredictedTextChange: { predictedText in
                onEditingTextChanged(predictedText, pageSize)
            },
            onSubmit: {
                onEditingSubmit()
            }
        )
        .frame(width: width, height: height)
        .clipped()
    }

    func selectionBorder(isSelected: Bool, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .stroke(
                isSelected ? .bg(.accent) : .clear,
                lineWidth: Constants.borderWidth
            )
            .frame(width: width, height: height)
    }

    private func textContent(_ item: DocumentTextItem, width: CGFloat, height: CGFloat) -> some View {
        Text(item.text)
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
    }
}

// MARK: - Move

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

                let newCenter = CGPoint(
                    x: session.initialCenterX + deltaX,
                    y: session.initialCenterY + deltaY
                )

                onTextMove(item.id, newCenter)
            }
            .onEnded { _ in
                moveSession = nil
            }
    }
}

// MARK: - Resize

private extension AddTextPageOverlayView {
    private func leftResizeHandle(
        _ item: DocumentTextItem,
        in size: CGSize,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        resizeHandle
            .position(x: 0, y: height / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if resizeSession?.textID != item.id || resizeSession?.side != .left {
                            resizeSession = ResizeSession(
                                textID: item.id,
                                side: .left,
                                initialWidth: item.width,
                                initialCenterX: item.centerX,
                                startLocationX: value.startLocation.x
                            )
                            onResizeStateChanged(true)
                        }

                        guard let session = resizeSession else { return }

                        let deltaXPoints = value.location.x - session.startLocationX
                        let deltaXNormalized = deltaXPoints / max(size.width, 1)

                        let minWidthNormalized = Constants.initialWidth / max(size.width, 1)

                        let rightEdge = session.initialCenterX + session.initialWidth / 2
                        let proposedWidth = session.initialWidth - deltaXNormalized
                        let clampedWidth = max(minWidthNormalized, min(proposedWidth, rightEdge))

                        let newCenterX = rightEdge - clampedWidth / 2
                        
                        let previewHeight = measuredPreviewHeight(
                            for: item,
                            widthNormalized: clampedWidth,
                            pageSize: size
                        )
                        
                        let previewCenterY = previewResizedCenterY(
                            for: item,
                            heightNormalized: previewHeight
                        )

                        activeResizeTextID = item.id
                        activeResizeWidth = clampedWidth
                        activeResizeHeight = previewHeight
                        activeResizeCenterX = newCenterX
                        activeResizeCenterY = previewCenterY
                    }
                    .onEnded { _ in
                        onResizeStateChanged(false)
                        finishResize(for: item, pageSize: size)
                    }
            )
    }

    private func rightResizeHandle(
        _ item: DocumentTextItem,
        in size: CGSize,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        resizeHandle
            .position(x: width, y: height / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if resizeSession?.textID != item.id || resizeSession?.side != .right {
                            resizeSession = ResizeSession(
                                textID: item.id,
                                side: .right,
                                initialWidth: item.width,
                                initialCenterX: item.centerX,
                                startLocationX: value.startLocation.x
                            )
                            onResizeStateChanged(true)
                        }

                        guard let session = resizeSession else { return }

                        let deltaXPoints = value.location.x - session.startLocationX
                        let deltaXNormalized = deltaXPoints / max(size.width, 1)

                        let minWidthNormalized = Constants.initialWidth / max(size.width, 1)

                        let leftEdge = session.initialCenterX - session.initialWidth / 2
                        let proposedWidth = session.initialWidth + deltaXNormalized
                        let maxWidth = 1 - leftEdge
                        let clampedWidth = max(minWidthNormalized, min(proposedWidth, maxWidth))

                        let newCenterX = leftEdge + clampedWidth / 2
                        
                        let previewHeight = measuredPreviewHeight(
                            for: item,
                            widthNormalized: clampedWidth,
                            pageSize: size
                        )
                        
                        let previewCenterY = previewResizedCenterY(
                            for: item,
                            heightNormalized: previewHeight
                        )

                        activeResizeTextID = item.id
                        activeResizeWidth = clampedWidth
                        activeResizeHeight = previewHeight
                        activeResizeCenterX = newCenterX
                        activeResizeCenterY = previewCenterY
                    }
                    .onEnded { _ in
                        onResizeStateChanged(false)
                        finishResize(for: item, pageSize: size)
                    }
            )
    }

    func finishResize(for item: DocumentTextItem, pageSize: CGSize) {
        guard let session = resizeSession else { return }

        let finalWidth = activeResizeWidth ?? session.initialWidth
        let finalCenterX = activeResizeCenterX ?? session.initialCenterX

        onTextResize(item.id, finalWidth, finalCenterX, pageSize)

        resizeSession = nil
        activeResizeTextID = nil
        activeResizeWidth = nil
        activeResizeHeight = nil
        activeResizeCenterX = nil
        activeResizeCenterY = nil
    }

    private var resizeHandle: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(
                    width: Constants.handleTouchSize.width,
                    height: Constants.handleTouchSize.height
                )

            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)

            Circle()
                .stroke(.bg(.accent), lineWidth: 4)
                .frame(
                    width: Constants.handleVisualSize,
                    height: Constants.handleVisualSize
                )
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Display Helpers

private extension AddTextPageOverlayView {
    func displayedWidth(for item: DocumentTextItem) -> CGFloat {
        guard activeResizeTextID == item.id else { return item.width }
        return activeResizeWidth ?? item.width
    }
    
    func displayedHeight(for item: DocumentTextItem) -> CGFloat {
        guard activeResizeTextID == item.id else { return item.height }
        return activeResizeHeight ?? item.height
    }

    func displayedCenterX(for item: DocumentTextItem) -> CGFloat {
        guard activeResizeTextID == item.id else { return item.centerX }
        return activeResizeCenterX ?? item.centerX
    }
    
    func displayedCenterY(for item: DocumentTextItem) -> CGFloat {
        guard activeResizeTextID == item.id else { return item.centerY }
        return activeResizeCenterY ?? item.centerY
    }
    
    func measuredPreviewHeight(
        for item: DocumentTextItem,
        widthNormalized: CGFloat,
        pageSize: CGSize
    ) -> CGFloat {
        let minHeightPoints: CGFloat = 44
        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8

        let widthPoints = widthNormalized * max(pageSize.width, 1)
        let availableTextWidth = max(widthPoints - horizontalInset * 2, 1)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: item.style.fontSize, weight: .regular),
            .kern: item.style.letterSpacing,
            .paragraphStyle: paragraph
        ]

        let sourceText = item.text.isEmpty ? " " : item.text
        let attributed = NSAttributedString(string: sourceText, attributes: attributes)

        let wrappedRect = attributed.boundingRect(
            with: CGSize(
                width: availableTextWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let heightPoints = max(ceil(wrappedRect.height) + verticalInset * 2, minHeightPoints)
        return heightPoints / max(pageSize.height, 1)
    }
    
    func previewResizedCenterY(
        for item: DocumentTextItem,
        heightNormalized: CGFloat
    ) -> CGFloat {
        let topEdgeY = item.centerY - item.height / 2
        return topEdgeY + heightNormalized / 2
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
}

// MARK: - Layout Helpers

private extension AddTextPageOverlayView {
    func textAlignment(for alignment: DocumentTextAlignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    func normalize(location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x / max(size.width, 1), 0), 1),
            y: min(max(location.y / max(size.height, 1), 0), 1)
        )
    }
}

// MARK: - Helper
extension AddTextPageOverlayView {
    private func uiTextAlignment(for alignment: DocumentTextAlignment) -> NSTextAlignment {
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}
