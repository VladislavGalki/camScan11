import SwiftUI

struct EraseView: View {
    @StateObject private var viewModel: EraseViewModel
    @State private var shouldShowDiscardConfirmation = false
    @State private var showBrushPreview = false
    @State private var brushPreviewTask: Task<Void, Never>?
    @EnvironmentObject private var router: Router

    private let presetColors: [String] = [
        "#FFFFFFFF",
        "#020202FF",
        "#BFBFBFFF"
    ]

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
            strokesByPage: viewModel.strokesByPage,
            selectedIndex: viewModel.selectedIndex,
            isAutoColor: viewModel.isAutoColor,
            eraseColor: viewModel.activeColor,
            brushSize: viewModel.brushSize,
            delegate: viewModel
        )
    }

    var bottomPanel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(presetColors, id: \.self) { hex in
                        presetColorItem(hex: hex)

                        Spacer(minLength: 0)
                    }

                    nativeColorPicker
                        .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Text("Auto color")
                        .appTextStyle(.bodySecondary)
                        .foregroundStyle(.text(.secondary))

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.isAutoColor },
                            set: { viewModel.setAutoColorEnabled($0) }
                        )
                    )
                        .labelsHidden()
                        .tint(.bg(.accent))
                }
            }

            sliderBlock(
                title: "Size",
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
                    range: 4...40
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
                                .fill(Color.black)
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
        .overlay(alignment: .topLeading) {
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
                .offset(y: -48)
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

    func presetColorItem(hex: String) -> some View {
        let normalizedHex = normalized(hex)
        let selectedHex = normalized(viewModel.manualColor.toRGBAHex() ?? "#FFFFFFFF")
        let isSelected = !viewModel.isAutoColor && normalizedHex == selectedHex
        let isWhite = normalizedHex == "#FFFFFFFF"
        let swatchColor = Color(rgbaHex: hex) ?? .clear
        let innerSize: CGFloat = isSelected && !isWhite ? 26 : 32

        return Button {
            guard let color = Color(rgbaHex: normalizedHex) else { return }
            viewModel.selectManualColor(color)
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
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#E5E5E5") ?? .clear)
                            .frame(width: 22, height: 22)
                    }

                    Circle()
                        .stroke(
                            Color.black.opacity(0.08),
                            lineWidth: 1
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
                    viewModel.manualColor
                },
                set: { newValue in
                    viewModel.selectManualColor(newValue)
                }
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
