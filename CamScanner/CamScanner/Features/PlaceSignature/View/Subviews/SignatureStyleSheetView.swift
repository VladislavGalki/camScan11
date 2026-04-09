import SwiftUI

struct SignatureStyleSheetView: View {
    let initialColorHex: String
    let initialThickness: CGFloat

    let onColorChanged: (String) -> Void
    let onThicknessChanged: (CGFloat) -> Void

    @State private var colorHex: String
    @State private var thickness: CGFloat

    @State private var showBrushPreview = false
    @State private var brushPreviewTask: Task<Void, Never>?

    private let presetColors: [String] = [
        "#020202FF",
        "#BFBFBFFF",
        "#2961F6FF",
        "#64C367FF",
        "#EF8B01FF",
        "#EA4D3EFF"
    ]

    init(
        initialColorHex: String,
        initialThickness: CGFloat,
        onColorChanged: @escaping (String) -> Void,
        onThicknessChanged: @escaping (CGFloat) -> Void
    ) {
        self.initialColorHex = initialColorHex
        self.initialThickness = initialThickness
        self.onColorChanged = onColorChanged
        self.onThicknessChanged = onThicknessChanged
        _colorHex = State(initialValue: initialColorHex)
        _thickness = State(initialValue: initialThickness)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(presetColors, id: \.self) { hex in
                    presetColorItem(hex: hex)

                    Spacer(minLength: 0)
                }

                nativeColorPicker
            }

            sliderBlock(
                title: "Thickness",
                valueText: "\(Int(thickness.rounded()))"
            ) {
                AppSlider(
                    value: Binding(
                        get: { thickness },
                        set: { newValue in
                            thickness = newValue
                            onThicknessChanged(newValue)
                            showBrushSizePreview()
                        }
                    ),
                    range: 4...16
                )
            }
            .overlay(alignment: .top) {
                if showBrushPreview {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .frame(width: 96, height: 68)
                        .foregroundStyle(.bg(.surface))
                        .appBorderModifier(.border(.primary), radius: 8)
                        .overlay {
                            Circle()
                                .fill(Color(rgbaHex: colorHex) ?? .black)
                                .overlay(
                                    Circle()
                                        .stroke(Color.border(.primary), lineWidth: 0.5)
                                )
                                .frame(width: thickness, height: thickness)
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                        .offset(y: -48)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Color.bg(.surface))
    }

    // MARK: - Color Items

    private func presetColorItem(hex: String) -> some View {
        let normalizedHex = normalized(hex)
        let selectedHex = normalized(colorHex)
        let isSelected = normalizedHex == selectedHex
        let swatchColor = Color(rgbaHex: hex) ?? .clear
        let innerSize: CGFloat = isSelected ? 26 : 32

        return Button {
            colorHex = normalizedHex
            onColorChanged(normalizedHex)
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(swatchColor, lineWidth: 3)
                        .frame(width: 32, height: 32)
                }

                Circle()
                    .fill(swatchColor)
                    .frame(width: innerSize, height: innerSize)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private var nativeColorPicker: some View {
        ColorPicker(
            "",
            selection: Binding(
                get: { Color(rgbaHex: colorHex) ?? .black },
                set: { newValue in
                    let hex = newValue.toRGBAHex() ?? "#020202FF"
                    colorHex = hex
                    onColorChanged(hex)
                }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .scaleEffect(1.35)
        .frame(width: 34, height: 34)
    }

    // MARK: - Slider

    private func sliderBlock<Content: View>(
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
    }

    // MARK: - Helpers

    private func normalized(_ hex: String) -> String {
        hex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }

    private func showBrushSizePreview() {
        brushPreviewTask?.cancel()
        showBrushPreview = true

        brushPreviewTask = Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showBrushPreview = false
            }
        }
    }
}
