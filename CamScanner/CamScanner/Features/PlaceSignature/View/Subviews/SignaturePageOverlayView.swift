import SwiftUI

// MARK: - Session Models

private struct MoveSession: Equatable {
    let signatureID: UUID
    let initialCenterX: CGFloat
    let initialCenterY: CGFloat
}

private struct ResizeRotateSession {
    let signatureID: UUID
    let initialDistance: CGFloat
    let initialAngle: CGFloat
    let initialWidth: CGFloat
    let initialHeight: CGFloat
    let initialRotation: CGFloat
}

// MARK: - View

struct SignaturePageOverlayView: View {
    private enum Constants {
        static let borderWidth: CGFloat = 2
        static let handleSize: CGFloat = 20
        /// Extra padding around the handle to reach 44pt minimum touch target
        static let handleHitExtra: CGFloat = 12
    }

    // MARK: - State

    @State private var moveSession: MoveSession?
    @State private var resizeRotateSession: ResizeRotateSession?

    // MARK: - Input

    let pageIndex: Int
    let items: [DocumentSignatureItem]
    let selectedSignatureID: UUID?
    let isInteractionDisabled: Bool
    weak var delegate: SignaturePageDelegate?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                pageTapLayer

                ForEach(items) { item in
                    signatureBlock(item, in: geo.size)
                        .position(
                            x: item.centerX * geo.size.width,
                            y: item.centerY * geo.size.height
                        )
                }
            }
            .coordinateSpace(name: "signaturePage")
            .onAppear { delegate?.didChangePageSize(geo.size) }
            .onChange(of: geo.size) { _, newSize in
                delegate?.didChangePageSize(newSize)
            }
            .allowsHitTesting(!isInteractionDisabled)
        }
    }
}

// MARK: - Tap Layer

private extension SignaturePageOverlayView {
    var pageTapLayer: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .onTapGesture {
                delegate?.didTapPage(index: pageIndex)
            }
    }
}

// MARK: - Signature Block

private extension SignaturePageOverlayView {
    func signatureBlock(_ item: DocumentSignatureItem, in size: CGSize) -> some View {
        let width = item.width * size.width
        let height = item.height * size.height
        let isSelected = item.id == selectedSignatureID

        return ZStack(alignment: .bottomTrailing) {
            // Main body: border + image + move gesture
            ZStack {
                // Selection border
                Rectangle()
                    .stroke(isSelected ? .bg(.accent) : .clear, lineWidth: Constants.borderWidth)
                    .frame(width: width, height: height)

                // Signature image
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width - 4, height: height - 4)
                        .opacity(item.opacity)
                } else {
                    Color.clear
                        .frame(width: width - 4, height: height - 4)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(moveGesture(for: item, in: size))
            .highPriorityGesture(
                TapGesture().onEnded { delegate?.didTapSignature(id: item.id) }
            )

            // Resize/rotate handle — outside the contentShape so it gets its own hit area
            if isSelected {
                ZStack {
                    Circle()
                        .fill(Color.bg(.accent))
                        .frame(width: Constants.handleSize, height: Constants.handleSize)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                }
                    .padding(Constants.handleHitExtra)
                    .contentShape(Circle().size(
                        width: Constants.handleSize + Constants.handleHitExtra * 2,
                        height: Constants.handleSize + Constants.handleHitExtra * 2
                    ))
                    .offset(
                        x: Constants.handleSize / 2 - 2 + Constants.handleHitExtra,
                        y: Constants.handleSize / 2 - 2 + Constants.handleHitExtra
                    )
                    .gesture(resizeRotateGesture(for: item, in: size))
            }
        }
        .rotationEffect(.degrees(item.rotation))
        .frame(width: width + Constants.handleSize + Constants.handleHitExtra * 2,
               height: height + Constants.handleSize + Constants.handleHitExtra * 2)
    }
}

// MARK: - Move Gesture

private extension SignaturePageOverlayView {
    func moveGesture(for item: DocumentSignatureItem, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if moveSession?.signatureID != item.id {
                    moveSession = MoveSession(
                        signatureID: item.id,
                        initialCenterX: item.centerX,
                        initialCenterY: item.centerY
                    )
                }

                guard let session = moveSession else { return }

                let deltaX = value.translation.width / max(size.width, 1)
                let deltaY = value.translation.height / max(size.height, 1)

                delegate?.didMoveSignature(
                    id: item.id,
                    to: CGPoint(
                        x: session.initialCenterX + deltaX,
                        y: session.initialCenterY + deltaY
                    )
                )
            }
            .onEnded { _ in moveSession = nil }
    }
}

// MARK: - Resize + Rotate Gesture

private extension SignaturePageOverlayView {
    func resizeRotateGesture(for item: DocumentSignatureItem, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("signaturePage"))
            .onChanged { value in
                let centerPt = CGPoint(
                    x: item.centerX * size.width,
                    y: item.centerY * size.height
                )

                if resizeRotateSession?.signatureID != item.id {
                    let startPt = value.startLocation
                    let dx = startPt.x - centerPt.x
                    let dy = startPt.y - centerPt.y
                    let distance = sqrt(dx * dx + dy * dy)
                    let angle = atan2(dy, dx) * 180 / .pi

                    resizeRotateSession = ResizeRotateSession(
                        signatureID: item.id,
                        initialDistance: max(distance, 1),
                        initialAngle: angle,
                        initialWidth: item.width,
                        initialHeight: item.height,
                        initialRotation: item.rotation
                    )
                }

                guard let session = resizeRotateSession else { return }

                let currentPt = value.location
                let dx = currentPt.x - centerPt.x
                let dy = currentPt.y - centerPt.y
                let currentDistance = sqrt(dx * dx + dy * dy)
                let currentAngle = atan2(dy, dx) * 180 / .pi

                let scaleFactor = currentDistance / max(session.initialDistance, 1)
                let newWidth = session.initialWidth * scaleFactor
                let newHeight = session.initialHeight * scaleFactor

                let deltaAngle = currentAngle - session.initialAngle
                let newRotation = session.initialRotation + deltaAngle

                delegate?.didResizeRotateSignature(
                    id: item.id,
                    width: newWidth,
                    height: newHeight,
                    rotation: newRotation
                )
            }
            .onEnded { _ in
                if let session = resizeRotateSession {
                    delegate?.didEndResizeRotate(id: session.signatureID)
                }
                resizeRotateSession = nil
            }
    }
}

// MARK: - Hit Testing

private extension SignaturePageOverlayView {
    func hitTestItem(at location: CGPoint, in size: CGSize) -> DocumentSignatureItem? {
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
