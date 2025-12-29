import SwiftUI
import UIKit

struct DocumentCropperView: View {

    let originalImage: UIImage
    let autoQuad: Quadrilateral?

    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    @State private var action: CropperAction? = nil

    var body: some View {
        ZStack {
            CropperControllerRepresentable(
                image: originalImage,
                autoQuad: autoQuad,
                action: $action,
                onCropped: { cropped in
                    onDone(cropped)
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                    }
                    .foregroundColor(.black)

                    Spacer()

                    Text("Обр.")
                        .font(.system(size: 17, weight: .semibold))

                    Spacer()

                    Button {
                        action = .commit
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                    }
                    .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .background(Color.white.opacity(0.95))

                Spacer()

                // Bottom actions (CamScanner-like)
                HStack(spacing: 0) {
                    Button { action = .rotateLeft } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "rotate.left")
                            Text("Влево").font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Button { action = .rotateRight } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "rotate.right")
                            Text("Вправо").font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Button { action = .setAuto } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text("Автообрезка").font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Button { action = .setAll } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Все").font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .foregroundColor(.black)
                .background(Color.white.opacity(0.95))
            }
        }
    }
}

private enum CropperAction: Equatable {
    case rotateLeft
    case rotateRight
    case setAll
    case setAuto
    case commit
}

private struct CropperControllerRepresentable: UIViewControllerRepresentable {

    let image: UIImage
    let autoQuad: Quadrilateral?

    @Binding var action: CropperAction?
    let onCropped: (UIImage) -> Void

    func makeUIViewController(context: Context) -> DocumentCropViewController {
        let vc = DocumentCropViewController(image: image, autoQuad: autoQuad)
        vc.onCropped = { cropped in
            onCropped(cropped)
        }
        context.coordinator.vc = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: DocumentCropViewController, context: Context) {
        guard let currentAction = action else { return }

        // ✅ НЕЛЬЗЯ: action = nil синхронно внутри update cycle
        DispatchQueue.main.async {
            self.action = nil
        }

        switch currentAction {
        case .rotateLeft:
            uiViewController.rotateLeft()
        case .rotateRight:
            uiViewController.rotateRight()
        case .setAll:
            uiViewController.setAllQuad()
        case .setAuto:
            uiViewController.setAutoQuad()
        case .commit:
            uiViewController.commitCrop()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var vc: DocumentCropViewController?
    }
}
