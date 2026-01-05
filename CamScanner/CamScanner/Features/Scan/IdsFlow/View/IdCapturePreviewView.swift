import SwiftUI
import UIKit

struct IdCapturePreviewView: View {

    let result: IdCaptureResult

    /// ✅ чтобы применить результат редактирования (в VM)
    let onEdit: (_ side: IdCaptureSide, _ croppedOriginal: UIImage, _ quad: Quadrilateral) -> Void
    let onDone: () -> Void
    let onRetake: () -> Void

    @State private var showCropper = false
    @State private var editingSide: IdCaptureSide = .front

    // ✅ фильтры на превью
    @State private var selectedFilter: PreviewFilter = .original
    @State private var filteredFront: UIImage?
    @State private var filteredBack: UIImage?

    // ✅ compare state (press & hold)
    @State private var isComparingOriginal: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            cropperSheet
        }
        .onAppear {
            recomputeFilters()
        }
        .onChange(of: selectedFilter) { _, _ in
            recomputeFilters()
        }
    }

    private func recomputeFilters() {
        let front = result.front.preview
        let back = result.back?.preview

        DispatchQueue.global(qos: .userInitiated).async {
            // OmniFix если у тебя "soon" — он и так внутри FilterEngine возвращает оригинал
            let fFront = front.map { FilterEngine.shared.apply(selectedFilter, to: $0) }
            let fBack  = back.map  { FilterEngine.shared.apply(selectedFilter, to: $0) }

            DispatchQueue.main.async {
                self.filteredFront = fFront
                self.filteredBack = fBack
            }
        }
    }

    // MARK: - Display helpers

    private var frontDisplayImage: UIImage? {
        if isComparingOriginal { return result.front.preview }
        return filteredFront ?? result.front.preview
    }

    private var backDisplayImage: UIImage? {
        if isComparingOriginal { return result.back?.preview }
        return filteredBack ?? result.back?.preview
    }

    private var isCompareEnabled: Bool {
        selectedFilter != .original
    }

    @ViewBuilder
    private var content: some View {
        if result.requiresBackSide {
            VStack(spacing: 12) {
                if let img = frontDisplayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Лицевая")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture {
                            editingSide = .front
                        }
                }

                if let img = backDisplayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Оборот")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture {
                            editingSide = .back
                        }
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 170) // ✅ чуть больше из-за фильтров
            .padding(.horizontal, 16)

        } else {
            if let img = frontDisplayImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 56)
                    .padding(.bottom, 170)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onRetake) {
                Text("Переснять")
                    .font(.system(size: 17, weight: .regular))
            }
            .foregroundColor(.blue)

            Spacer()

            Text(result.idType.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: onDone) {
                Text("Готово")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {

            FiltersCarouselView(selected: $selectedFilter)

            if result.requiresBackSide {
                HStack(spacing: 12) {
                    Button {
                        editingSide = .front
                    } label: {
                        Text("Лицевая")
                            .font(.system(size: 13, weight: editingSide == .front ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(editingSide == .front ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button {
                        editingSide = .back
                    } label: {
                        Text("Оборот")
                            .font(.system(size: 13, weight: editingSide == .back ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(editingSide == .back ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(.white)
            }

            // ✅ Compare + Crop row
            HStack(spacing: 12) {

                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                        Text("Сравнить")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(isCompareEnabled ? 0.10 : 0.05))
                    .foregroundColor(Color.white.opacity(isCompareEnabled ? 1.0 : 0.45))
                    .clipShape(Capsule())
                }
                .disabled(!isCompareEnabled)
                .onLongPressGesture(
                    minimumDuration: 0.01,
                    maximumDistance: 60,
                    pressing: { pressing in
                        guard isCompareEnabled else { return }
                        isComparingOriginal = pressing
                    },
                    perform: {}
                )

                Button {
                    showCropper = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crop")
                        Text("Обрезка")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 22)
        .padding(.top, 10)
        .background(Color.black.opacity(0.001))
    }

    @ViewBuilder
    private var cropperSheet: some View {
        let source: UIImage? = {
            switch editingSide {
            case .front: return result.front.original
            case .back:  return result.back?.original
            }
        }()

        let quad: Quadrilateral? = {
            switch editingSide {
            case .front: return result.front.quad
            case .back:  return result.back?.quad
            }
        }()

        if let source {
            DocumentCropperView(
                originalImage: source,
                autoQuad: quad,
                onCancel: { showCropper = false },
                onDone: { cropped, newQuad in
                    onEdit(editingSide, cropped, newQuad)   // ✅
                    showCropper = false
                }
            )
        } else {
            Color.black.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
                .onAppear { showCropper = false }
        }
    }
}
