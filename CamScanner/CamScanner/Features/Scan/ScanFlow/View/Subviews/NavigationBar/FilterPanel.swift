import SwiftUI

struct FiltersPanel: View {

    let selected: ScanFilter
    let onSelect: (ScanFilter) -> Void

    private let items: [ScanFilter] = [.original, .cancelShadows, .eco, .gray, .bw]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            ForEach(items) { f in
                Button {
                    onSelect(f)
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(f == selected ? 0.14 : 0.08))
                            .frame(height: 52)
                            .overlay(
                                Image(systemName: icon(for: f))
                                    .foregroundStyle(f == selected ? .cyan : .white.opacity(0.9))
                            )

                        Text(f.rawValue)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 30)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func icon(for f: ScanFilter) -> String {
        switch f {
        case .original: return "doc.text"
        case .eco: return "leaf"
        case .gray: return "circle.lefthalf.filled"
        case .bw: return "circle.dashed"
        case .cancelShadows: return "sun.max"
        }
    }
}
