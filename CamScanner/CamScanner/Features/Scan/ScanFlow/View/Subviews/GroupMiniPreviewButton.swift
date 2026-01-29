import SwiftUI
import UIKit

struct GroupMiniPreviewButton: View {

    let isVisible: Bool
    let image: UIImage?
    let count: Int
    let onTap: () -> Void

    @ViewBuilder
    var body: some View {
        Group {
            if isVisible, let image {
                Button(action: onTap) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipped()
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
