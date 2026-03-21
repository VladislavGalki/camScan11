import Foundation

enum OpenCVBWThresholdMode: String, CaseIterable, Identifiable {
    case otsu
    case adaptiveGaussian
    case adaptiveMean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .otsu: return "Otsu"
        case .adaptiveGaussian: return "Adaptive Gaussian"
        case .adaptiveMean: return "Adaptive Mean"
        }
    }
}

struct OpenCVTuningParams: Equatable {
    var shadowSigma: Double = 31

    var bwClipLimit: Double = 1.8
    var bwAlpha: Double = 1.08
    var bwBeta: Double = 0.0

    var bwMedianBlurSize: Int = 3
    var bwThresholdMode: OpenCVBWThresholdMode = .otsu
    var bwThresholdBlockSize: Int = 17
    var bwThresholdC: Double = 4.0

    var bwOpenKernelSize: Int = 1
    var bwCloseKernelSize: Int = 2

    var bwBorderInset: Int = 6
    var bwEnableBorderCleanup: Bool = true

    var perfectClipLimit: Double = 2.2
    var perfectAlpha: Double = 1.12
    var perfectBeta: Double = -6.0
    var perfectSharpenEdge: Float = -0.7
    var perfectSharpenCenter: Float = 3.8

    static let `default` = OpenCVTuningParams()
}

import Foundation

enum OpenCVTuningFilterType: String, CaseIterable, Identifiable {
    case blackWhite
    case perfect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blackWhite: return "B&W"
        case .perfect: return "Perfect"
        }
    }
}

import Foundation
import UIKit
import opencv2

final class OpenCVDebugRenderer {
    func render(
        image: UIImage,
        filter: OpenCVTuningFilterType,
        params: OpenCVTuningParams
    ) -> UIImage? {
        switch filter {
        case .blackWhite:
            return renderBlackWhite(image: image, params: params)
        case .perfect:
            return renderPerfect(image: image, params: params)
        }
    }
}

private extension OpenCVDebugRenderer {
    func renderBlackWhite(
        image: UIImage,
        params: OpenCVTuningParams
    ) -> UIImage? {
        let source = Mat(uiImage: image)
        let gray = toGray(source)
        let normalized = removeShadows(from: gray, sigma: params.shadowSigma)

        let claheOutput = Mat()
        let clahe = Imgproc.createCLAHE(
            clipLimit: params.bwClipLimit,
            tileGridSize: Size2i(width: 8, height: 8)
        )
        clahe.apply(src: normalized, dst: claheOutput)

        let contrasted = Mat()
        claheOutput.convert(
            to: contrasted,
            rtype: CvType.CV_8U,
            alpha: params.bwAlpha,
            beta: params.bwBeta
        )

        let denoised = Mat()
        let medianSize = correctedOddKernel(params.bwMedianBlurSize, min: 1)
        if medianSize > 1 {
            Imgproc.medianBlur(src: contrasted, dst: denoised, ksize: Int32(medianSize))
        } else {
            contrasted.copy(to: denoised)
        }

        let binary = Mat()

        switch params.bwThresholdMode {
        case .otsu:
            let thresholdType = ThresholdTypes(
                rawValue: ThresholdTypes.THRESH_BINARY.rawValue |
                ThresholdTypes.THRESH_OTSU.rawValue
            )!
            Imgproc.threshold(
                src: denoised,
                dst: binary,
                thresh: 0,
                maxval: 255,
                type: thresholdType
            )

        case .adaptiveGaussian:
            Imgproc.adaptiveThreshold(
                src: denoised,
                dst: binary,
                maxValue: 255,
                adaptiveMethod: .ADAPTIVE_THRESH_GAUSSIAN_C,
                thresholdType: .THRESH_BINARY,
                blockSize: Int32(correctedOddKernel(params.bwThresholdBlockSize, min: 3)),
                C: params.bwThresholdC
            )

        case .adaptiveMean:
            Imgproc.adaptiveThreshold(
                src: denoised,
                dst: binary,
                maxValue: 255,
                adaptiveMethod: .ADAPTIVE_THRESH_MEAN_C,
                thresholdType: .THRESH_BINARY,
                blockSize: Int32(correctedOddKernel(params.bwThresholdBlockSize, min: 3)),
                C: params.bwThresholdC
            )
        }

        let afterOpen = Mat()
        let afterClose = Mat()

        let openSize = max(1, params.bwOpenKernelSize)
        let closeSize = max(1, params.bwCloseKernelSize)

        if openSize > 1 {
            let openKernel = Imgproc.getStructuringElement(
                shape: .MORPH_RECT,
                ksize: Size2i(width: Int32(openSize), height: Int32(openSize))
            )
            Imgproc.morphologyEx(
                src: binary,
                dst: afterOpen,
                op: .MORPH_OPEN,
                kernel: openKernel
            )
        } else {
            binary.copy(to: afterOpen)
        }

        if closeSize > 1 {
            let closeKernel = Imgproc.getStructuringElement(
                shape: .MORPH_RECT,
                ksize: Size2i(width: Int32(closeSize), height: Int32(closeSize))
            )
            Imgproc.morphologyEx(
                src: afterOpen,
                dst: afterClose,
                op: .MORPH_CLOSE,
                kernel: closeKernel
            )
        } else {
            afterOpen.copy(to: afterClose)
        }

        let cleaned = params.bwEnableBorderCleanup
            ? cleanupBorders(from: afterClose, inset: params.bwBorderInset)
            : afterClose

        return cleaned.toUIImage()
    }

    func renderPerfect(
        image: UIImage,
        params: OpenCVTuningParams
    ) -> UIImage? {
        let source = Mat(uiImage: image)
        let gray = toGray(source)
        let normalized = removeShadows(from: gray, sigma: params.shadowSigma)

        let claheOutput = Mat()
        let clahe = Imgproc.createCLAHE(
            clipLimit: params.perfectClipLimit,
            tileGridSize: Size2i(width: 8, height: 8)
        )
        clahe.apply(src: normalized, dst: claheOutput)

        let smoothed = Mat()
        Imgproc.GaussianBlur(
            src: claheOutput,
            dst: smoothed,
            ksize: Size2i(width: 3, height: 3),
            sigmaX: 0
        )

        let enhanced = Mat()
        smoothed.convert(
            to: enhanced,
            rtype: CvType.CV_8U,
            alpha: params.perfectAlpha,
            beta: params.perfectBeta
        )

        let sharpened = Mat()
        let kernel = Mat(rows: 3, cols: 3, type: CvType.CV_32F)
        try? kernel.put(row: 0, col: 0, data: [
            Float(0), params.perfectSharpenEdge, Float(0),
            params.perfectSharpenEdge, params.perfectSharpenCenter, params.perfectSharpenEdge,
            Float(0), params.perfectSharpenEdge, Float(0)
        ])

        Imgproc.filter2D(
            src: enhanced,
            dst: sharpened,
            ddepth: -1,
            kernel: kernel
        )

        return sharpened.toUIImage()
    }

    func toGray(_ source: Mat) -> Mat {
        let gray = Mat()

        if source.channels() == 4 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_RGBA2GRAY)
        } else if source.channels() == 3 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_RGB2GRAY)
        } else {
            source.copy(to: gray)
        }

        return gray
    }

    func removeShadows(from gray: Mat, sigma: Double) -> Mat {
        let background = Mat()
        Imgproc.GaussianBlur(
            src: gray,
            dst: background,
            ksize: Size2i(width: 0, height: 0),
            sigmaX: sigma
        )

        let grayFloat = Mat()
        let backgroundFloat = Mat()
        gray.convert(to: grayFloat, rtype: CvType.CV_32F)
        background.convert(to: backgroundFloat, rtype: CvType.CV_32F)

        let normalizedFloat = Mat()
        Core.divide(
            src1: grayFloat,
            src2: backgroundFloat,
            dst: normalizedFloat,
            scale: 255.0
        )

        let normalized = Mat()
        normalizedFloat.convert(to: normalized, rtype: CvType.CV_8U)

        return normalized
    }
    
    func correctedOddKernel(_ value: Int, min: Int) -> Int {
        let clamped = max(min, value)
        return clamped.isMultiple(of: 2) ? clamped + 1 : clamped
    }

    func cleanupBorders(from binary: Mat, inset: Int) -> Mat {
        let result = Mat()
        binary.copy(to: result)

        let width = Int(result.cols())
        let height = Int(result.rows())
        let safeInset = max(0, min(inset, min(width, height) / 8))

        guard safeInset > 0 else { return result }

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: 0),
            pt2: Point(x: Int32(width), y: Int32(safeInset)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: Int32(height - safeInset)),
            pt2: Point(x: Int32(width), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: 0),
            pt2: Point(x: Int32(safeInset), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: Int32(width - safeInset), y: 0),
            pt2: Point(x: Int32(width), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        return result
    }
}

import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class OpenCVFilterDebugViewModel: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var selectedFilter: OpenCVTuningFilterType = .blackWhite
    @Published var params: OpenCVTuningParams = .default
    @Published var isRendering = false

    private let renderer = OpenCVDebugRenderer()
    private var renderTask: Task<Void, Never>?

    func setImage(_ image: UIImage?) {
        originalImage = image

        if let image {
            previewImage = image.downscaled(maxDimension: 1000)
        } else {
            previewImage = nil
        }

        render()
    }

    func resetParams() {
        params = .default
        render()
    }

    func render() {
        guard let previewImage else {
            processedImage = nil
            return
        }

        renderTask?.cancel()
        isRendering = true

        let image = previewImage
        let filter = selectedFilter
        let params = params

        renderTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let result = await self.renderer.render(
                image: image,
                filter: filter,
                params: params
            )

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.processedImage = result
                self.isRendering = false
            }
        }
    }

    func printParams() {
        print("=== OpenCV Params ===")
        print(params)
    }
}

struct OpenCVFilterDebugView: View {
    @StateObject private var viewModel = OpenCVFilterDebugViewModel()
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                imageSection(
                    title: "Original",
                    image: viewModel.originalImage
                )

                imageSection(
                    title: "Processed",
                    image: viewModel.processedImage
                )

                controls
            }
            .padding(16)
        }
        .background(Color.bg(.main).ignoresSafeArea())
        .onChange(of: viewModel.selectedFilter) { _ in
            viewModel.render()
        }
        .onChange(of: photoItem) { newValue in
            loadPhoto(from: newValue)
        }
    }
}

private extension OpenCVFilterDebugView {
    var header: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Load Image")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(OpenCVTuningFilterType.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button("Reset") {
                    viewModel.resetParams()
                }
                .buttonStyle(.bordered)

                Button("Print Params") {
                    viewModel.printParams()
                }
                .buttonStyle(.bordered)

                if viewModel.isRendering {
                    ProgressView()
                }
            }
        }
    }

    func imageSection(title: String, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(height: 380)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .padding(12)
                } else {
                    Text("No image")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var controls: some View {
        VStack(spacing: 16) {
            slider("Shadow Sigma", value: binding(\.shadowSigma), range: 5...80)

            switch viewModel.selectedFilter {
            case .blackWhite:
                slider("B&W CLAHE", value: binding(\.bwClipLimit), range: 0.5...5.0)
                slider("B&W Alpha", value: binding(\.bwAlpha), range: 0.8...1.6)
                slider("B&W Beta", value: binding(\.bwBeta), range: -20...20)

                intSlider("Median Blur", value: intBinding(\.bwMedianBlurSize), range: 1...9, step: 2)

                bwThresholdModePicker

                intSlider("B&W Block", value: intBinding(\.bwThresholdBlockSize), range: 3...41, step: 2)
                slider("B&W C", value: binding(\.bwThresholdC), range: 0...15)

                intSlider("Open Kernel", value: intBinding(\.bwOpenKernelSize), range: 1...5, step: 1)
                intSlider("Close Kernel", value: intBinding(\.bwCloseKernelSize), range: 1...5, step: 1)

                Toggle("Border Cleanup", isOn: boolBinding(\.bwEnableBorderCleanup))
                intSlider("Border Inset", value: intBinding(\.bwBorderInset), range: 0...20, step: 1)

            case .perfect:
                slider("Perfect CLAHE", value: binding(\.perfectClipLimit), range: 0.5...5.0)
                slider("Perfect Alpha", value: binding(\.perfectAlpha), range: 0.8...1.6)
                slider("Perfect Beta", value: binding(\.perfectBeta), range: -20...20)
                slider("Sharpen Edge", value: floatBinding(\.perfectSharpenEdge), range: -2.0...0.0)
                slider("Sharpen Center", value: floatBinding(\.perfectSharpenCenter), range: 1.0...6.0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bg(.surface))
        )
    }

    func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
                .font(.subheadline)

            Slider(value: value, in: range)
        }
    }

    func slider(
        _ title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
                .font(.subheadline)

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Float($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }

    func intSlider(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(value.wrappedValue)")
                .font(.subheadline)

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
        }
    }
    
    var bwThresholdModePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Threshold Mode")
                .font(.subheadline)

            Picker("Threshold Mode", selection: thresholdModeBinding()) {
                ForEach(OpenCVBWThresholdMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    func boolBinding(_ keyPath: WritableKeyPath<OpenCVTuningParams, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.params[keyPath: keyPath] },
            set: { newValue in
                var copy = viewModel.params
                copy[keyPath: keyPath] = newValue
                viewModel.params = copy
                viewModel.render()
            }
        )
    }

    func thresholdModeBinding() -> Binding<OpenCVBWThresholdMode> {
        Binding(
            get: { viewModel.params.bwThresholdMode },
            set: { newValue in
                var copy = viewModel.params
                copy.bwThresholdMode = newValue
                viewModel.params = copy
                viewModel.render()
            }
        )
    }

    func binding(_ keyPath: WritableKeyPath<OpenCVTuningParams, Double>) -> Binding<Double> {
        Binding(
            get: { viewModel.params[keyPath: keyPath] },
            set: { newValue in
                var copy = viewModel.params
                copy[keyPath: keyPath] = newValue
                viewModel.params = copy
                viewModel.render()
            }
        )
    }

    func floatBinding(_ keyPath: WritableKeyPath<OpenCVTuningParams, Float>) -> Binding<Float> {
        Binding(
            get: { viewModel.params[keyPath: keyPath] },
            set: { newValue in
                var copy = viewModel.params
                copy[keyPath: keyPath] = newValue
                viewModel.params = copy
                viewModel.render()
            }
        )
    }

    func intBinding(_ keyPath: WritableKeyPath<OpenCVTuningParams, Int>) -> Binding<Int> {
        Binding(
            get: { viewModel.params[keyPath: keyPath] },
            set: { newValue in
                var copy = viewModel.params
                let corrected = keyPath == \.bwThresholdBlockSize
                    ? max(3, newValue | 1)
                    : newValue
                copy[keyPath: keyPath] = corrected
                viewModel.params = copy
                viewModel.render()
            }
        )
    }

    func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }

            viewModel.setImage(image)
        }
    }
}
