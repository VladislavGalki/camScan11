import SwiftUI

struct CreateSignatureView: View {
    @StateObject private var viewModel = CreateSignatureViewModel()
    @State private var showBrushPreview = false
    @State private var brushPreviewTask: Task<Void, Never>?
    @State private var strokesRevision: Int = 0
    @EnvironmentObject private var router: Router

    private let presetColors: [String] = [
        "#020202FF",
        "#BFBFBFFF",
        "#2961F6FF",
        "#64C367FF",
        "#EF8B01FF",
        "#EA4D3EFF"
    ]

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .padding(.bottom, 12)

            canvasArea
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            bottomPanel
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.bg(.main).ignoresSafeArea())
    }
}

// MARK: - Subviews

private extension CreateSignatureView {
    var navigationBar: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: { router.dismissSheet() }
            )

            Spacer(minLength: 0)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: { router.dismissSheet() }
            )
            .appButtonEnabled(!viewModel.isEmpty)
        }
        .overlay {
            Text("Create a signature")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }

    var canvasArea: some View {
        GeometryReader { geo in
            let canvasSize = geo.size

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.bg(.surface))

                if viewModel.isEmpty && viewModel.currentPoints.isEmpty {
                    Text("Sign here")
                        .appTextStyle(.screenTitle)
                        .foregroundStyle(.text(.tertiary))
                }

                Canvas(rendersAsynchronously: false) { ctx, size in
                    let currentColor = viewModel.selectedColor
                    let minSide = max(1, min(size.width, size.height))
                    let currentWidthPx = CGFloat(viewModel.brushSize) / minSide * minSide

                    for s in viewModel.strokes {
                        drawStroke(s, in: ctx, canvasSize: size, color: currentColor, widthPx: currentWidthPx)
                    }

                    if !viewModel.currentPoints.isEmpty {
                        let tempStroke = Stroke(
                            points: viewModel.currentPoints,
                            color: UIColor(currentColor),
                            opacity: 1.0,
                            widthN: 0
                        )
                        drawStroke(tempStroke, in: ctx, canvasSize: size, color: currentColor, widthPx: currentWidthPx)
                    }
                }
                .id("\(strokesRevision)_\(viewModel.selectedColorHex)_\(viewModel.brushSize)")
                .appBorderModifier(.border(.primary), radius: 32)
                .contentShape(Rectangle())
                .gesture(drawingGesture(canvasSize: canvasSize))

                VStack {
                    Spacer()
                    
                    HStack {
                        AppButton(
                            config: AppButtonConfig(
                                content: .title("Erase"),
                                style: .secondary,
                                size: .s
                            ),
                            action: {
                                viewModel.eraseAll()
                                strokesRevision &+= 1
                            }
                        )
                        .appButtonEnabled(!viewModel.isEmpty)
                        
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    var bottomPanel: some View {
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
                valueText: "\(Int(viewModel.brushSize.rounded()))"
            ) {
                AppSlider(
                    value: Binding(
                        get: { viewModel.brushSize },
                        set: { newValue in
                            viewModel.brushSize = newValue
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
                                .fill(viewModel.selectedColor)
                                .overlay(
                                    Circle()
                                        .stroke(Color.border(.primary), lineWidth: 0.5)
                                )
                                .frame(
                                    width: viewModel.brushSize,
                                    height: viewModel.brushSize
                                )
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                        .offset(y: -48)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    func presetColorItem(hex: String) -> some View {
        let normalizedHex = normalized(hex)
        let selectedHex = normalized(viewModel.selectedColorHex)
        let isSelected = normalizedHex == selectedHex
        let swatchColor = Color(rgbaHex: hex) ?? .clear
        let innerSize: CGFloat = isSelected ? 26 : 32

        return Button {
            viewModel.selectColorHex(normalizedHex)
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
                get: { viewModel.selectedColor },
                set: { viewModel.selectColor($0) }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .scaleEffect(1.35)
        .frame(width: 34, height: 34)
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
    }

    func normalized(_ hex: String) -> String {
        hex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }
}

// MARK: - Drawing

private extension CreateSignatureView {
    func drawingGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if let pN = toNormalized(value.location, canvasSize: canvasSize) {
                    viewModel.currentPoints.append(pN)
                }
            }
            .onEnded { _ in
                viewModel.commitStroke(canvasSize: canvasSize)
                strokesRevision &+= 1
            }
    }

    func drawStroke(_ s: Stroke, in ctx: GraphicsContext, canvasSize: CGSize, color: Color, widthPx: CGFloat) {
        guard !s.points.isEmpty else { return }

        var path = Path()
        let p0 = fromNormalized(s.points[0], canvasSize: canvasSize)
        path.move(to: p0)

        if s.points.count > 1 {
            for p in s.points.dropFirst() {
                path.addLine(to: fromNormalized(p, canvasSize: canvasSize))
            }
        } else {
            let r = max(1, widthPx / 2)
            path.addEllipse(in: CGRect(x: p0.x - r, y: p0.y - r, width: 2 * r, height: 2 * r))
        }

        ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: widthPx, lineCap: .round, lineJoin: .round)
        )
    }

    func toNormalized(_ point: CGPoint, canvasSize: CGSize) -> CGPoint? {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return nil }
        let x = point.x / canvasSize.width
        let y = point.y / canvasSize.height
        guard x >= 0, x <= 1, y >= 0, y <= 1 else { return nil }
        return CGPoint(x: x, y: y)
    }

    func fromNormalized(_ pN: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: pN.x * canvasSize.width,
            y: pN.y * canvasSize.height
        )
    }
}

// MARK: - Actions

private extension CreateSignatureView {
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
