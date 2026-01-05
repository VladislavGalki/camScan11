import SwiftUI

struct FiltersCarouselView: View {

    @Binding var selected: PreviewFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(PreviewFilter.allCases) { f in
                    FilterChip(
                        title: f.title,
                        isSelected: selected == f,
                        isDisabled: f.isOmnifix
                    )
                    .onTapGesture {
                        selected = f
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.never)
        .padding(.vertical, 10)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.green.opacity(0.22) : Color.white.opacity(0.10))
                .frame(width: 86, height: 54)
                .overlay {
                    if isDisabled {
                        Text("SOON")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                    }
                }

            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(width: 92)
    }
}
