import SwiftUI

struct CapturePreviewView: View {
    
    let image: UIImage?
    let originalImage: UIImage?
    let autoQuad: Quadrilateral?

    let onDone: () -> Void
    let onRetake: () -> Void

    @StateObject var vm: ScanViewModel
    @State private var showCropper = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Переснять") { onRetake() }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Spacer()

                    Button("Готово") { onDone() }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                Spacer()

                // Bottom bar (как ты просил: пока одна кнопка)
                HStack {
                    Button {
                        showCropper = true
                    } label: {
                        Text("Обрезка")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                    }
                    .disabled(originalImage == nil)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let originalImage {
                DocumentCropperView(
                    originalImage: originalImage,
                    autoQuad: autoQuad,
                    onCancel: { showCropper = false },
                    onDone: { edited in
                        vm.applyEditedImage(edited)  // ✅ обновляем превью
                        showCropper = false
                    }
                )
            }
        }
    }
}
