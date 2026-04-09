import SwiftUI

struct SignatureStyleSheetView: View {
    enum Mode {
        case vector
        case raster
    }

    let mode: Mode
    let initialColorHex: String
    let initialThickness: CGFloat
    let initialOpacity: CGFloat

    let onColorChanged: (String) -> Void
    let onThicknessChanged: (CGFloat) -> Void
    let onOpacityChanged: (CGFloat) -> Void

    @State private var colorHex: String
    @State private var thickness: CGFloat
    @State private var opacity: CGFloat

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
        mode: Mode = .vector,
        initialColorHex: String,
        initialThickness: CGFloat,
        initialOpacity: CGFloat = 1.0,
        onColorChanged: @escaping (String) -> Void,
        onThicknessChanged: @escaping (CGFloat) -> Void,
        onOpacityChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.mode = mode
        self.initialColorHex = initialColorHex
        self.initialThickness = initialThickness
        self.initialOpacity = initialOpacity
        self.onColorChanged = onColorChanged
        self.onThicknessChanged = onThicknessChanged
        self.onOpacityChanged = onOpacityChanged
        _colorHex = State(initialValue: initialColorHex)
        _thickness = State(initialValue: initialThickness)
        _opacity = State(initialValue: initialOpacity)
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

            switch mode {
            case .vector:
                thicknessSlider
            case .raster:
                opacitySlider
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Color.bg(.surface))
    }
}

// MARK: - Sliders

private extension SignatureStyleSheetView {
    var thicknessSlider: some View {
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

    var opacitySlider: some View {
        sliderBlock(
            title: "Opacity",
            valueText: "\(Int((opacity * 100).rounded()))%"
        ) {
            AppSlider(
                value: Binding(
                    get: { opacity },
                    set: { newValue in
                        opacity = newValue
                        onOpacityChanged(newValue)
                    }
                ),
                range: 0.1...1.0
            )
        }
    }
}

// MARK: - Color Items

private extension SignatureStyleSheetView {
    func presetColorItem(hex: String) -> some View {
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

    var nativeColorPicker: some View {
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
}

// MARK: - Slider Block

private extension SignatureStyleSheetView {
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
    }
}

// MARK: - Helpers

private extension SignatureStyleSheetView {
    func normalized(_ hex: String) -> String {
        hex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }

    func showBrushSizePreview() {
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
