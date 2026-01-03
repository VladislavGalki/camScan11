import SwiftUI
import UIKit

struct IdCapturePreviewView: View {

    let result: IdCaptureResult
    let onDone: () -> Void
    let onRetake: () -> Void

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
    }

    @ViewBuilder
    private var content: some View {
        if result.requiresBackSide {
            // 2 фото: показываем оба (как CamScanner-like превью)
            VStack(spacing: 12) {
                if let img = result.front.preview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                }

                if let img = result.back?.preview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 140)
            .padding(.horizontal, 16)

        } else {
            // 1 фото
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
                Text("Превью удостоверения (2 стороны)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("Превью удостоверения")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 32)
    }
}
