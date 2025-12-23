import SwiftUI

struct QualityPanel: View {

    let selected: QualityPreset
    let onSelect: (QualityPreset) -> Void

    var body: some View {
        HStack(spacing: 18) {
            qualityButton(.hd)
            qualityButton(.large)
            qualityButton(.standard)
            qualityButton(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func qualityButton(_ preset: QualityPreset) -> some View {
        Button {
            onSelect(preset)
        } label: {
            VStack(spacing: 6) {
                Text(preset.rawValue)
                    .font(.headline)
                    .foregroundStyle(preset == selected ? .cyan : .white)
                Text(preset.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(preset == selected ? 0.14 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
