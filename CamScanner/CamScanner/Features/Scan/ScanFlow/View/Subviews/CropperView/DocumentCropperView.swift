import SwiftUI
import UIKit

struct DocumentCropperView: View {
    let cropperModel: DocumentCropperModel

    let onCancel: () -> Void
    let onDone: (DocumentCropperModel) -> Void   // ✅

    @State private var action: CropperAction? = nil

    var body: some View {
        ZStack {
            DocumentCropperControllerRepresentable(
                cropperModel: cropperModel,
                action: $action,
                onCropped: { cropperModel in
                    DispatchQueue.main.async {
                        onDone(cropperModel)
                    }
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
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
