import SwiftUI

struct AddTextStyleSheetView: View {
    @Binding var draft: AddTextStyleDraft

    let onColorChanged: (String) -> Void
    let onFontSizeChanged: (CGFloat) -> Void
    let onRotationChanged: (CGFloat) -> Void
    let onClose: () -> Void

    private let presetColors: [String] = [
        "#020202FF", // black
        "#BFBFBFFF", // gray
        "#FFFFFFFF", // white
        "#2961F6FF", // blue
        "#64C367FF", // green
        "#EF8B01FF", // orange
        "#EA4D3EFF"  // red
    ]

    var body: some View {
        VStack(spacing: 0) {
            capsuleHandle
                .padding(.vertical, 8)

            colorRow
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            slidersRow
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(
            Color.bg(.surface)
        )
    }
}

// MARK: - Subviews

private extension AddTextStyleSheetView {
    var capsuleHandle: some View {
        Capsule()
            .foregroundStyle(Color(hex: "CCCCCC") ?? .gray.opacity(0.35))
            .frame(width: 36, height: 5)
    }

    var colorRow: some View {
        HStack(spacing: 0) {
            ForEach(presetColors, id: \.self) { hex in
                presetColorItem(hex: hex)
                
                Spacer(minLength: 0)
            }

            nativeColorPicker
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func presetColorItem(hex: String) -> some View {
        let normalizedHex = normalized(hex)
        let draftNormalizedHex = normalized(draft.colorHex)
        let isSelected = normalizedHex == draftNormalizedHex
        let isWhite = normalizedHex == "#FFFFFFFF"
        let swatchColor = Color(rgbaHex: hex) ?? .clear
        let innerSize: CGFloat = isSelected && !isWhite ? 26 : 32

        return Button {
            draft.colorHex = normalizedHex
            onColorChanged(normalizedHex)
        } label: {
            ZStack {
                if isSelected && !isWhite {
                    Circle()
                        .stroke(swatchColor, lineWidth: 3)
                        .frame(width: 32, height: 32)
                }

                Circle()
                    .fill(swatchColor)
                    .frame(width: innerSize, height: innerSize)

                if isWhite {
                    Circle()
                        .stroke(
                            isSelected ? Color.black.opacity(0.18) : Color.black.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    var nativeColorPicker: some View {
        ColorPicker(
            "",
            selection: Binding(
                get: {
                    Color(rgbaHex: draft.colorHex) ?? .black
                },
                set: { newValue in
                    let hex = newValue.toRGBAHex() ?? "#020202FF"
                    draft.colorHex = hex
                    onColorChanged(hex)
                }
            ),
            supportsOpacity: true
        )
        .labelsHidden()
        .scaleEffect(1.35)
        .frame(width: 34, height: 34)
    }

    var slidersRow: some View {
        HStack(spacing: 16) {
            sliderBlock(
                title: "Font size",
                valueText: "\(Int(draft.fontSize))"
            ) {
                AppSlider(
                    value: Binding(
                        get: { draft.fontSize },
                        set: { newValue in
                            let rounded = round(newValue)
                            draft.fontSize = rounded
                            onFontSizeChanged(rounded)
                        }
                    ),
                    range: 12...32
                )
            }

            Rectangle()
                .fill(Color.divider(.default))
                .frame(width: 1, height: 50)

            sliderBlock(
                title: "Rotate",
                valueText: "\(Int(abs(draft.rotation) <= 5 ? 0 : draft.rotation))°"
            ) {
                AppSlider(
                    value: Binding(
                        get: { draft.rotation },
                        set: { newValue in
                            let rounded = round(newValue)
                            let snapped = abs(rounded) <= 5 ? 0 : rounded

                            draft.rotation = snapped
                            onRotationChanged(snapped)
                        }
                    ),
                    range: -180...180
                )
            }
        }
    }

    func sliderBlock<Content: View>(
        title: String,
        valueText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.secondary))

                Spacer()

                Text(valueText)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.secondary))
            }

            content()
        }
        .frame(maxWidth: .infinity)
    }

    func normalized(_ hex: String) -> String {
        hex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }
}
