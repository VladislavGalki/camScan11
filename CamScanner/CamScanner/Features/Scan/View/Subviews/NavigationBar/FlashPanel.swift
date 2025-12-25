import SwiftUI

struct FlashPanel: View {

    let selected: FlashMode
    let onSelect: (FlashMode) -> Void

    var body: some View {
        HStack(spacing: 18) {
            flashButton(.off)
            flashButton(.on)
            flashButton(.auto)
            flashButton(.torch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func flashButton(_ mode: FlashMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            Text(mode.rawValue)
                .font(.headline)
                .foregroundStyle(mode == selected ? .cyan : .white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.white.opacity(mode == selected ? 0.14 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
