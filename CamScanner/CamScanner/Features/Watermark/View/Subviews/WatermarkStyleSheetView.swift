import UIKit
import SwiftUI

struct WatermarkStyleSheetView: View {
    @State private var didSnapToZero = false
    @Binding var draft: WatermarkStyleDraft

    let onColorChanged: (String) -> Void
    let onFontSizeChanged: (CGFloat) -> Void
    let onRotationChanged: (CGFloat) -> Void
    let onOpacityChanged: (CGFloat) -> Void
    let onClose: () -> Void

    private let presetColors: [String] = [
        "#020202FF",
        "#BFBFBFFF",
        "#FFFFFFFF",
        "#2961F6FF",
        "#64C367FF",
        "#EF8B01FF",
        "#EA4D3EFF"
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

private extension WatermarkStyleSheetView {
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
        VStack(spacing: 12) {
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
                    valueText: "\(Int(abs(draft.rotation) <= 5 ? 0 : draft.rotation))\u{00B0}"
                ) {
                    AppSlider(
                        value: Binding(
                            get: { draft.rotation },
                            set: { newValue in
                                let rounded = round(newValue)
                                let isInSnapZone = abs(rounded) <= 5
                                let snapped = isInSnapZone ? 0 : rounded

                                if isInSnapZone && !didSnapToZero {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.prepare()
                                    generator.impactOccurred()

                                    didSnapToZero = true
                                } else if !isInSnapZone {
                                    didSnapToZero = false
                                }

                                draft.rotation = snapped
                                onRotationChanged(snapped)
                            }
                        ),
                        range: -180...180
                    )
                }
            }

            sliderBlock(
                title: "Opacity",
                valueText: "\(Int(draft.opacity * 100))%"
            ) {
                AppSlider(
                    value: Binding(
                        get: { draft.opacity },
                        set: { newValue in
                            let rounded = round(newValue * 100) / 100
                            draft.opacity = rounded
                            onOpacityChanged(rounded)
                        }
                    ),
                    range: 0...1
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
