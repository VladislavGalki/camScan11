import SwiftUI

struct DocumentTypeCarouselView: View {
    var body: some View {
        HStack(spacing: 22) {
            Text("Скан")
                .foregroundStyle(.cyan)
                .font(.headline)
        }
        .padding(.vertical, 6)
    }
}
