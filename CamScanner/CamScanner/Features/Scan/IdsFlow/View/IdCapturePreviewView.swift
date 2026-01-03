import SwiftUI
import UIKit

struct IdCapturePreviewView: View {

    let result: IdCaptureResult

    /// ✅ чтобы применить результат редактирования (в VM)
    let onEdit: (_ side: IdCaptureSide, _ croppedOriginal: UIImage, _ quad: Quadrilateral) -> Void
    let onDone: () -> Void
    let onRetake: () -> Void

    @State private var showCropper = false
    @State private var editingSide: IdCaptureSide = .front

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            cropperSheet
        }
    }

    @ViewBuilder
    private var content: some View {
        if result.requiresBackSide {
            VStack(spacing: 12) {
                if let img = result.front.preview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Лицевая")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture {
                            // удобно: тап по изображению выбирает сторону для редактирования
                            editingSide = .front
                        }
                }

                if let img = result.back?.preview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Оборот")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture {
                            editingSide = .back
                        }
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 140)
            .padding(.horizontal, 16)

        } else {
            if let img = result.front.preview {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 56)
                    .padding(.bottom, 140)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onRetake) {
                Text("Переснять")
                    .font(.system(size: 17, weight: .regular))
            }
            .foregroundColor(.blue)

            Spacer()

            Text(result.idType.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: onDone) {
                Text("Готово")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {

            if result.requiresBackSide {
                // ✅ выбор стороны для редактирования
                HStack(spacing: 12) {
                    Button {
                        editingSide = .front
                    } label: {
                        Text("Лицевая")
                            .font(.system(size: 13, weight: editingSide == .front ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(editingSide == .front ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button {
                        editingSide = .back
                    } label: {
                        Text("Оборот")
                            .font(.system(size: 13, weight: editingSide == .back ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(editingSide == .back ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(.white)
            }

            // ✅ кнопка “Обрезка” как в Scan
            Button {
                showCropper = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crop")
                    Text("Обрезка")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.10))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding(.horizontal, 16)
            }

        }
        .padding(.bottom, 32)
        .padding(.top, 10)
        .background(Color.black.opacity(0.001)) // чтобы не ломать hit-testing
    }

    @ViewBuilder
    private var cropperSheet: some View {
        // Берём original именно выбранной стороны
        let source: UIImage? = {
            switch editingSide {
            case .front: return result.front.original
            case .back:  return result.back?.original
            }
        }()

        // quad (если когда-нибудь будем хранить)
        let quad: Quadrilateral? = {
            switch editingSide {
            case .front: return result.front.quad
            case .back:  return result.back?.quad
            }
        }()

        if let source {
            DocumentCropperView(
                originalImage: source,
                autoQuad: quad,
                onCancel: { showCropper = false },
                onDone: { cropped, newQuad in
                    onEdit(editingSide, cropped, newQuad)   // ✅
                    showCropper = false
                }
            )
        } else {
            // fallback на случай если original пустой (не должен быть при ready)
            Color.black.ignoresSafeArea()
                .overlay {
                    ProgressView().tint(.white)
                }
                .onAppear { showCropper = false }
        }
    }
}
