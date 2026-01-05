import SwiftUI

struct CapturePreviewView: View {

    let image: UIImage?
    let originalImage: UIImage?
    let autoQuad: Quadrilateral?

    let onDone: () -> Void
    let onRetake: () -> Void

    @StateObject var vm: ScanViewModel
    @State private var showCropper = false

    @State private var selectedFilter: PreviewFilter = .original
    @State private var filteredImage: UIImage?

    // ✅ compare state
    @State private var isComparingOriginal: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ✅ Если держим compare — показываем БЕЗ фильтра
            if let display = displayImage {
                Image(uiImage: display)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Переснять") { onRetake() }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Spacer()

                    Button("Готово") { onDone() }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                Spacer()

                bottomBar
            }
        }
        .onAppear { recalcFilter() }
        .onChange(of: selectedFilter) { _, _ in recalcFilter() }
        .onChange(of: image) { _, _ in recalcFilter() }
        .fullScreenCover(isPresented: $showCropper) {
            if let originalImage {
                DocumentCropperView(
                    originalImage: originalImage,
                    autoQuad: autoQuad,
                    onCancel: { showCropper = false },
                    onDone: { edited, _ in
                        vm.applyEditedImage(edited)
                        DispatchQueue.main.async {
                            showCropper = false
                            recalcFilter(for: edited)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Display

    private var displayImage: UIImage? {
        if isComparingOriginal {
            return image // ✅ без фильтра
        }
        return filteredImage ?? image
    }

    // MARK: - UI

    private var bottomBar: some View {
        VStack(spacing: 12) {

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(PreviewFilter.allCases, id: \.self) { f in
                        filterChip(f)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)

            HStack(spacing: 12) {

                // ✅ Compare button (press & hold)
                compareButton
                    .frame(width: 120)

                Button {
                    showCropper = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crop")
                        Text("Обрезка")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(originalImage == nil)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 22)
    }

    private var compareButton: some View {
        let isEnabled = (selectedFilter != .original)

        return Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                Text("Сравнить")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(isEnabled ? 0.12 : 0.06))
            .foregroundColor(Color.white.opacity(isEnabled ? 1.0 : 0.45))
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
        // ✅ "pressing" callback даёт начало/конец удержания
        .onLongPressGesture(
            minimumDuration: 0.01,
            maximumDistance: 50,
            pressing: { pressing in
                guard isEnabled else { return }
                isComparingOriginal = pressing
            },
            perform: {}
        )
    }

    private func filterChip(_ f: PreviewFilter) -> some View {
        let isSelected = (f == selectedFilter)

        return Text(f.title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.85))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))
            )
            .onTapGesture { selectedFilter = f }
    }

    // MARK: - Filter

    private func recalcFilter(for base: UIImage? = nil) {
        let src = base ?? image
        guard let src else {
            filteredImage = nil
            return
        }

        if selectedFilter == .original {
            filteredImage = nil
            return
        }

        filteredImage = FilterEngine.shared.apply(selectedFilter, to: src)
    }
}
