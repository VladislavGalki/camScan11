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

    // ✅ export state
    @State private var showExportDialog: Bool = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet: Bool = false

    // ✅ OCR state
    @State private var showOCR = false
    @State private var ocrText: String = ""
    @State private var isOCRLoading: Bool = false

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
        .sheet(isPresented: $showShareSheet) {
            if shareItems.count > 0 {
                DocumentExporterSheet(items: shareItems) {
                    self.shareItems = []
                }
            }
        }
        .sheet(isPresented: $showOCR) {
            OCREditorView(title: "Текст (OCR)", text: $ocrText) {
                showOCR = false
            }
        }
        .confirmationDialog("Экспорт", isPresented: $showExportDialog, titleVisibility: .visible) {
            ForEach(DocumentExportFormat.allCases) { format in
                Button(format.rawValue) {
                    export(format: format)
                }
                .disabled(!format.isImplemented)
            }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear { recomputeFilters() }
        .onChange(of: selectedFilter) { _, _ in
            recomputeFilters()
        }
    }

    // MARK: - Export

    private func export(format: DocumentExportFormat) {
        let images = exportImages()
        guard !images.isEmpty else { return }

        let baseName = "ID_\(result.idType.title)"

        DocumentExporter.shared.exportOrSave(
            images: images,
            format: format,
            fileName: baseName
        ) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                self.shareItems = urls
                self.showShareSheet = true
            case .failure:
                break
            }
        }
    }

    private func exportImages() -> [UIImage] {
        func pick(original: UIImage?, filtered: UIImage?) -> UIImage? {
            if selectedFilter == .original { return original }
            return filtered ?? original
        }

        var out: [UIImage] = []
        if let f = pick(original: result.front.preview, filtered: filteredFront) { out.append(f) }
        if result.requiresBackSide, let b = pick(original: result.back?.preview, filtered: filteredBack) { out.append(b) }
        return out
    }

    // MARK: - OCR

    private func runOCR() {
        guard !isOCRLoading else { return }

        let images = exportImages()
        guard !images.isEmpty else { return }

        isOCRLoading = true
        ocrText = ""

        Task {
            var blocks: [String] = []
            let total = images.count

            for (idx, img) in images.enumerated() {
                let pageTitle = "СТРАНИЦА \(idx + 1)/\(total)"
                do {
                    let res = try await OCRService.shared.recognizeText(in: img)
                    blocks.append("\(pageTitle)\n\(res.text)")
                } catch {
                    blocks.append("\(pageTitle)\n(ошибка OCR)")
                }
            }

            await MainActor.run {
                self.ocrText = blocks.joined(separator: "\n\n")
                self.isOCRLoading = false
                self.showOCR = true
            }
        }
    }

    // MARK: - Filters

    private func recomputeFilters() {
        let front = result.front.preview
        let back = result.back?.preview
        let filter = selectedFilter

        DispatchQueue.global(qos: .userInitiated).async {
            let fFront = front.map { FilterEngine.shared.apply(filter, to: $0) }
            let fBack  = back.map  { FilterEngine.shared.apply(filter, to: $0) }

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
                        .onTapGesture { editingSide = .front }
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
                        .onTapGesture { editingSide = .back }
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 170)
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

            Button {
                showExportDialog = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)

            Button {
                saveToDatabaseAndFinish()
            } label: {
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
                    Button { editingSide = .front } label: {
                        Text("Лицевая")
                            .font(.system(size: 13, weight: editingSide == .front ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(editingSide == .front ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button { editingSide = .back } label: {
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

            // ✅ Compare + OCR + Crop row
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
                    runOCR()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                        Text(isOCRLoading ? "OCR..." : "Текст")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(isOCRLoading)

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
                    onEdit(editingSide, cropped, newQuad)
                    showCropper = false
                }
            )
        } else {
            Color.black.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
                .onAppear { showCropper = false }
        }
    }

    // MARK: - Save to DB (ID)

    private func saveToDatabaseAndFinish() {
        var inputs: [DocumentRepository.PageInput] = []

        if let frontOriginal = result.front.original {
            inputs.append(.init(
                image: frontOriginal,
                quad: result.front.quad,
                filterRaw: selectedFilter.persistKey
            ))
        }

        if result.requiresBackSide, let backOriginal = result.back?.original {
            inputs.append(.init(
                image: backOriginal,
                quad: result.back?.quad,
                filterRaw: selectedFilter.persistKey
            ))
        }

        guard !inputs.isEmpty else {
            onDone()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DocumentRepository.shared.saveDocument(
                    kind: .id,
                    idTypeRaw: result.idType.id,              // у тебя id = title
                    rememberedFilterRaw: selectedFilter.persistKey,
                    pages: inputs
                )
                DispatchQueue.main.async { onDone() }
            } catch {
                print("!!! Error saving document: \(error)")
            }
        }
    }
}
