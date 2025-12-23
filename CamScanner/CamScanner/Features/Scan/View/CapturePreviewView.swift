import SwiftUI
import UIKit

struct CapturePreviewView: View {
    let image: UIImage?
    let onDone: () -> Void
    let onRetake: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("No image")
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Переснять") { onRetake() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { onDone() }
                }
            }
        }
    }
}
