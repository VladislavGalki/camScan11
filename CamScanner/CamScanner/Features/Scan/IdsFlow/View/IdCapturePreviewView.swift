import SwiftUI
import UIKit

struct IdCapturePreviewView: View {

    let image: UIImage?
    let originalImage: UIImage?
    let autoQuad: Quadrilateral?
    let idType: IdDocumentTypeEnum

    let onDone: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 56)
                    .padding(.bottom, 140)
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
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

            Text(idType.title)
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
            // здесь позже добавим “Обрезка/Фильтры/Тени/…” если нужно
            Text("Превью удостоверения")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 32)
    }
}
