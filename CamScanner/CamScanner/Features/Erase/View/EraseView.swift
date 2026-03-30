import SwiftUI

struct EraseView: View {
    @StateObject private var viewModel: EraseViewModel
    @State private var shouldShowDiscardConfirmation = false
    @State private var showBrushPreview = false
    @State private var brushPreviewTask: Task<Void, Never>?
    @EnvironmentObject private var router: Router

    init(inputModel: EraseInputModel) {
        _viewModel = StateObject(wrappedValue: EraseViewModel(inputModel: inputModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .padding(.bottom, 16)

            pageIndicator
                .padding(.bottom, 51)

            carouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 49)

            bottomPanel
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.bg(.main).ignoresSafeArea())
        .overlay {
            if shouldShowDiscardConfirmation {
                discardConfirmationOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension EraseView {
    var navigationBar: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.arrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: { handleBack() }
            )

            Spacer(minLength: 0)

            if viewModel.hasAnyChanges {
                HStack(spacing: 8) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .iconOnly(.back),
                            style: .secondary,
                            size: .s
                        ),
                        action: { viewModel.undo() }
                    )
                    .appButtonEnabled(viewModel.canUndo)

                    AppButton(
                        config: AppButtonConfig(
                            content: .iconOnly(.forward),
                            style: .secondary,
                            size: .s
                        ),
                        action: { viewModel.redo() }
                    )
                    .appButtonEnabled(viewModel.canRedo)
                }
            }

            Spacer(minLength: 0)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: { saveAndDismiss() }
            )
            .appButtonEnabled(viewModel.hasAnyChanges)
        }
        .overlay {
            Text("Erase")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .top)
        )
    }

    var pageIndicator: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.selectedIndex + 1)/\(viewModel.models.count)")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.onOverlay))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .foregroundStyle(.bg(.overlay))
                )
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var carouselView: some View {
        EraseCarouselRepresentable(
            models: viewModel.models,
            strokes: viewModel.currentStrokes,
            eraseColor: viewModel.activeColor,
            brushSize: viewModel.brushSize,
            delegate: viewModel
        )
    }

    var bottomPanel: some View {
        VStack(spacing: 16) {
            // Auto color toggle
            HStack {
                Text("Auto color")
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.primary))
                Spacer()
                Toggle("", isOn: $viewModel.isAutoColor)
                    .labelsHidden()
                    .tint(.bg(.accent))
            }

            // Manual color picker
            if !viewModel.isAutoColor {
                colorPickerRow
            }

            // Brush size slider
            VStack(spacing: 12) {
                if showBrushPreview {
                    brushStrokePreview
                        .transition(.opacity)
                }

                HStack(spacing: 12) {
                    Text("Size")
                        .appTextStyle(.bodySecondary)
                        .foregroundStyle(.text(.primary))
                        .frame(width: 32, alignment: .leading)

                    AppSlider(
                        value: Binding(
                            get: { viewModel.brushSize },
                            set: { newValue in
                                viewModel.brushSize = newValue
                                showBrushSizePreview()
                            }
                        ),
                        range: 4...40
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    var colorPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(erasePresetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    color == .white
                                        ? Color.border(.primary)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    viewModel.manualColor == color
                                        ? .bg(.accent)
                                        : Color.clear,
                                    lineWidth: 2.5
                                )
                                .padding(-3)
                        )
                        .onTapGesture {
                            viewModel.manualColor = color
                        }
                }
            }
        }
    }

    var brushStrokePreview: some View {
        BrushStrokeShape()
            .stroke(
                Color(UIColor(red: 0x20/255, green: 0x20/255, blue: 0x20/255, alpha: 1)),
                style: StrokeStyle(
                    lineWidth: viewModel.brushSize,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: 65, height: 36)
            .frame(maxWidth: .infinity)
    }

    var discardConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text("Discard changes?")
                    .appTextStyle(.topBarTitle)
                    .foregroundStyle(.text(.primary))

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Discard"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            shouldShowDiscardConfirmation = false
                            router.pop()
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            shouldShowDiscardConfirmation = false
                        }
                    )
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(
                Color.bg(.surface)
                    .cornerRadius(24, corners: .allCorners)
            )
        }
    }
}

// MARK: - Actions

private extension EraseView {
    func handleBack() {
        if viewModel.hasAnyChanges {
            shouldShowDiscardConfirmation = true
        } else {
            router.pop()
        }
    }

    func saveAndDismiss() {
        viewModel.save()
        router.pop()
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

    var erasePresetColors: [Color] {
        [.white, Color(white: 0.9), Color(white: 0.7), Color(white: 0.5), Color(white: 0.3), .black]
    }
}

// MARK: - Brush Stroke Shape

private struct BrushStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.65))
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.1),
            control1: CGPoint(x: w * 0.08, y: h * 0.35),
            control2: CGPoint(x: w * 0.2, y: h * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.7),
            control1: CGPoint(x: w * 0.5, y: h * 0.15),
            control2: CGPoint(x: w * 0.1, y: h * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.15),
            control1: CGPoint(x: w * 0.25, y: h * 0.9),
            control2: CGPoint(x: w * 0.6, y: h * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.85),
            control1: CGPoint(x: w * 0.9, y: h * 0.2),
            control2: CGPoint(x: w * 0.5, y: h * 0.7)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.95),
            control1: CGPoint(x: w * 0.6, y: h * 1.0),
            control2: CGPoint(x: w * 0.85, y: h * 0.95)
        )
        return path
    }
}
