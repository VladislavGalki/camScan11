import UIKit
import SwiftUI

struct WatermarkStyleSheetView: View {
    @State private var didSnapToZero = false
    @Binding var draft: WatermarkStyleDraft
    @Binding var placementMode: WatermarkPlacementMode

    let onColorChanged: (String) -> Void
    let onFontSizeChanged: (CGFloat) -> Void
    let onRotationChanged: (CGFloat) -> Void
    let onOpacityChanged: (CGFloat) -> Void
    let onModeChanged: (WatermarkPlacementMode) -> Void
    let onTileTextChanged: (String) -> Void
    let onDeleteTile: () -> Void
    let onClose: () -> Void

    @State private var tileText: String = "Watermark"

    private let presetColors: [String] = [
        "#020202FF",
        "#BFBFBFFF",
        "#FFFFFFFF"
    ]

    var body: some View {
        VStack(spacing: 0) {
            capsuleHandle
                .padding(.vertical, 8)

            segmentControl
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if placementMode == .tile {
                tileTextRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

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

    var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(WatermarkPlacementMode.allCases, id: \.self) { mode in
                segmentButton(mode)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.bg(.surface))
                .appBorderModifier(.border(.primary), radius: 10)
        )
    }

    func segmentButton(_ mode: WatermarkPlacementMode) -> some View {
        let isSelected = placementMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                placementMode = mode
                onModeChanged(mode)
            }
        } label: {
            Text(mode.rawValue)
                .appTextStyle(.bodySecondary)
                .foregroundStyle(isSelected ? .text(.primary) : .text(.secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.bg(.accent).opacity(0.12))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    var tileTextRow: some View {
        HStack(spacing: 8) {
            TextField("Watermark text", text: $tileText)
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.primary))
                .onSubmit {
                    onTileTextChanged(tileText)
                }
                .onChange(of: tileText) { _, newValue in
                    onTileTextChanged(newValue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.bg(.surface))
                        .appBorderModifier(.border(.primary), radius: 10)
                )

            Button {
                onDeleteTile()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.text(.destructive))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.bg(.surface))
                            .appBorderModifier(.border(.primary), radius: 10)
                    )
            }
            .buttonStyle(.plain)
        }
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
