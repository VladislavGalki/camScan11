import SwiftUI
import UIKit

struct DrawingEditorView: View {
    // Input
    let baseImage: UIImage
    let initialStrokes: [Stroke]
    let onCancel: () -> Void
    let onSave: (_ merged: UIImage, _ strokes: [Stroke]) -> Void

    // State
    @State private var tool: DrawingTool = .pen
    @State private var showPenOptions: Bool = false

    // Pen settings (only for NEW strokes)
    @State private var penColor: Color = .red
    @State private var penOpacity: Double = 1.0
    @State private var penWidth: Double = 8.0

    // Drawing data
    @State private var strokesRevision: Int = 0
    @State private var strokes: [Stroke] = []
    @State private var currentPoints: [CGPoint] = []

    // Eraser behavior
    @State private var erasedInThisGesture: Bool = false
    
    init(baseImage: UIImage, initialStrokes: [Stroke], onCancel: @escaping () -> Void, onSave: @escaping (UIImage, [Stroke]) -> Void) {
        self.baseImage = baseImage
        self.initialStrokes = initialStrokes
        self.onCancel = onCancel
        self.onSave = onSave
        _strokes = State(initialValue: initialStrokes)
        strokesRevision &+= 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let canvasSize = geo.size
                let imageRect = aspectFitRect(imageSize: baseImage.size, in: canvasSize)

                ZStack {
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: canvasSize.width, maxHeight: canvasSize.height)
                        .clipped()

                    Canvas(rendersAsynchronously: false) { ctx, _ in
                        // existing strokes
                        for s in strokes {
                            guard s.points.count >= 1 else { continue }

                            var path = Path()
                            let p0 = fromNormalized(s.points[0], imageRect: imageRect)
                            path.move(to: p0)

                            if s.points.count > 1 {
                                for p in s.points.dropFirst() {
                                    path.addLine(to: fromNormalized(p, imageRect: imageRect))
                                }
                            } else {
                                let widthPx = s.widthN * min(imageRect.width, imageRect.height)
                                let r = max(1, widthPx / 2)
                                path.addEllipse(in: CGRect(x: p0.x - r, y: p0.y - r, width: 2*r, height: 2*r))
                            }

                            let widthPx = s.widthN * min(imageRect.width, imageRect.height)
                            ctx.stroke(
                                path,
                                with: .color(Color(s.color).opacity(s.opacity)),
                                style: StrokeStyle(lineWidth: widthPx, lineCap: .round, lineJoin: .round)
                            )
                        }

                        // current in-progress stroke
                        if tool == .pen, currentPoints.count >= 1 {
                            let ui = UIColor(penColor)
                            var path = Path()

                            let p0 = fromNormalized(currentPoints[0], imageRect: imageRect)
                            path.move(to: p0)

                            if currentPoints.count > 1 {
                                for p in currentPoints.dropFirst() {
                                    path.addLine(to: fromNormalized(p, imageRect: imageRect))
                                }
                            } else {
                                let widthN = CGFloat(penWidth) / max(1, min(imageRect.width, imageRect.height))
                                let widthPx = widthN * min(imageRect.width, imageRect.height)
                                let r = max(1, widthPx / 2)
                                path.addEllipse(in: CGRect(x: p0.x - r, y: p0.y - r, width: 2*r, height: 2*r))
                            }

                            let widthN = CGFloat(penWidth) / max(1, min(imageRect.width, imageRect.height))
                            let widthPx = widthN * min(imageRect.width, imageRect.height)

                            ctx.stroke(
                                path,
                                with: .color(Color(ui).opacity(penOpacity)),
                                style: StrokeStyle(lineWidth: widthPx, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .id(strokesRevision)
                    .contentShape(Rectangle())
                    .gesture(drawingGesture(imageRect: imageRect))
                }
            }

            // top bar
            VStack(spacing: 0) {
                HStack {
                    Button("Назад") { onCancel() }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Spacer()

                    Button("Сохранить") {
                        let merged = renderMergedImage()
                        onSave(merged, strokes)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Spacer()
            }

            // bottom bar
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        tool = .pen
                        showPenOptions = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                            Text("Перо")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(tool == .pen ? 0.18 : 0.10))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }

                    Button {
                        tool = .eraser
                        showPenOptions = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eraser")
                            Text("Ластик")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(tool == .eraser ? 0.18 : 0.10))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }

            // ✅ pen options overlay + close on tap outside
            if showPenOptions {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showPenOptions = false }   // ✅ FIX #1

                penOptionsSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Gesture

    private func drawingGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                switch tool {
                case .pen:
                    if let pN = toNormalized(value.location, imageRect: imageRect) {
                        currentPoints.append(pN)
                    }

                case .eraser:
                    guard !erasedInThisGesture else { return }
                    if eraseNearestStroke(at: value.location, imageRect: imageRect) {
                        erasedInThisGesture = true
                    }
                }
            }
            .onEnded { _ in
                switch tool {
                case .pen:
                    if !currentPoints.isEmpty {
                        let minSide = max(1, min(imageRect.width, imageRect.height))
                        let widthN = CGFloat(penWidth) / minSide

                        let new = Stroke(
                            points: currentPoints,
                            color: UIColor(penColor),
                            opacity: penOpacity, widthN: max(0.001, widthN)
                        )
                        strokes.append(new)
                        strokesRevision &+= 1
                    }
                    currentPoints = []

                case .eraser:
                    erasedInThisGesture = false
                }
            }
    }

    private func eraseNearestStroke(at pointView: CGPoint, imageRect: CGRect) -> Bool {
        guard !strokes.isEmpty else { return false }

        // tolerance в пикселях
        let tolerance: CGFloat = 22

        // хиттест: bbox в view-space
        func hit(_ s: Stroke) -> Bool {
            guard let first = s.points.first else { return false }
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in s.points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }

            let tl = fromNormalized(CGPoint(x: minX, y: minY), imageRect: imageRect)
            let br = fromNormalized(CGPoint(x: maxX, y: maxY), imageRect: imageRect)

            let rect = CGRect(
                x: min(tl.x, br.x),
                y: min(tl.y, br.y),
                width: abs(br.x - tl.x),
                height: abs(br.y - tl.y)
            ).insetBy(dx: -tolerance, dy: -tolerance)

            return rect.contains(pointView)
        }

        if let idx = strokes.lastIndex(where: { hit($0) }) {
            strokes.remove(at: idx)
            strokesRevision &+= 1
            return true
        }
        return false
    }

    // MARK: - Pen options UI

    private var penOptionsSheet: some View {
        VStack(spacing: 12) {
            // colors
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(presetColors, id: \.self) { c in
                        Circle()
                            .fill(c)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.white.opacity(penColor == c ? 0.9 : 0.0), lineWidth: 2)
                            )
                            .onTapGesture { penColor = c }
                    }

                    ColorPicker("", selection: $penColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 40, height: 28)
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)

            // opacity
            VStack(alignment: .leading, spacing: 6) {
                Text("Прозрачность")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Slider(value: $penOpacity, in: 0.1...1.0)
            }
            .padding(.horizontal, 16)

            // width
            VStack(alignment: .leading, spacing: 6) {
                Text("Размер")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Slider(value: $penWidth, in: 2...26)
            }
            .padding(.horizontal, 16)

            // preview circle
            Circle()
                .fill(penColor.opacity(penOpacity))
                .frame(width: CGFloat(penWidth), height: CGFloat(penWidth))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .padding(.top, 4)
                .padding(.bottom, 12)

        }
        .padding(.top, 14)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var presetColors: [Color] {
        [
            .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink, .white, .black
        ]
    }

    // MARK: - Render merged image

    private func renderMergedImage() -> UIImage {
        let base = baseImage.normalizedUp()
        let size = base.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))

            for s in strokes {
                guard !s.points.isEmpty else { continue }

                let color = s.color.withAlphaComponent(s.opacity)
                color.setStroke()

                let path = UIBezierPath()
                let ptsPx = s.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

                path.move(to: ptsPx[0])

                if ptsPx.count > 1 {
                    for p in ptsPx.dropFirst() { path.addLine(to: p) }
                } else {
                    // точка
                    let lw = s.widthN * min(size.width, size.height)
                    let r = max(1, lw / 2)
                    path.append(UIBezierPath(ovalIn: CGRect(x: ptsPx[0].x - r, y: ptsPx[0].y - r, width: 2*r, height: 2*r)))
                }

                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.lineWidth = s.widthN * min(size.width, size.height)
                path.stroke()
            }
        }
    }
    
    private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func toNormalized(_ pView: CGPoint, imageRect: CGRect) -> CGPoint? {
        guard imageRect.width > 1, imageRect.height > 1, imageRect.contains(pView) else { return nil }
        let x = (pView.x - imageRect.minX) / imageRect.width
        let y = (pView.y - imageRect.minY) / imageRect.height
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private func fromNormalized(_ pN: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + pN.x * imageRect.width,
            y: imageRect.minY + pN.y * imageRect.height
        )
    }
}
