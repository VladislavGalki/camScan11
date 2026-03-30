import UIKit

final class DrawingCanvasUIView: UIView {

    // MARK: - Public state
    var tool: DrawingTool = .pen
    var penColor: UIColor = .systemRed
    var penAlpha: CGFloat = 1.0
    /// В UI по-прежнему задаём в px на экране
    var penWidth: CGFloat = 6.0

    /// ✅ rect картинки ВНУТРИ canvas (aspectFit), задаётся снаружи (SwiftUI wrapper)
    private(set) var imageRectInView: CGRect = .zero

    var onStrokesChanged: (([Stroke]) -> Void)?
    var onTouchBegan: (() -> Void)?
    var onTouchEnded: (() -> Void)?

    private var suppressStrokesChangedCallback = false

    private(set) var strokes: [Stroke] = [] {
        didSet {
            guard !suppressStrokesChangedCallback else { return }
            onStrokesChanged?(strokes)
        }
    }

    // MARK: - Private
    private var currentStroke: Stroke?
    private var currentLayer: CAShapeLayer?

    private var strokeLayers: [UUID: CAShapeLayer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isMultipleTouchEnabled = false
        backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    // MARK: - External API

    /// ✅ Вызывай при каждом layout/обновлении (из SwiftUI wrapper),
    /// передавай реальный rect картинки в этом canvas (aspectFit)
    func setImageRectInView(_ rect: CGRect) {
        guard imageRectInView.integral != rect.integral else { return }
        imageRectInView = rect
        // если rect изменился — надо перерисовать слои
        redrawAllLayers()
    }

    func setStrokes(_ new: [Stroke]) {
        guard strokes != new else { return }

        // очистка
        strokeLayers.values.forEach { $0.removeFromSuperlayer() }
        strokeLayers.removeAll()

        suppressStrokesChangedCallback = true
        strokes = new
        suppressStrokesChangedCallback = false

        // перерисовка
        for s in strokes {
            let layer = makeLayer(for: s)
            strokeLayers[s.id] = layer
            self.layer.addSublayer(layer)
            updateLayerPath(layer, stroke: s)
        }
    }

    func clearAll() {
        setStrokes([])
    }

    // MARK: - Touch drawing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tool == .pen, let pView = touches.first?.location(in: self) else { return }
        guard imageRectInView.width > 1, imageRectInView.height > 1 else { return }
        guard imageRectInView.contains(pView) else { return } // ✅ вне картинки не рисуем

        onTouchBegan?()

        let pN = toNormalized(pView)

        // ✅ widthN фиксируем относительно imageRect (на экране)
        let minSide = max(1, min(imageRectInView.width, imageRectInView.height))
        let widthN = max(0.001, penWidth / minSide)

        let s = Stroke(points: [pN], color: penColor, opacity: penAlpha, widthN: widthN)
        currentStroke = s

        let layer = makeLayer(for: s)
        currentLayer = layer
        strokeLayers[s.id] = layer
        self.layer.addSublayer(layer)

        updateLayerPath(layer, stroke: s)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tool == .pen, let pView = touches.first?.location(in: self) else { return }
        guard imageRectInView.contains(pView) else { return }
        guard var s = currentStroke, let layer = currentLayer else { return }

        s.points.append(toNormalized(pView))
        currentStroke = s

        updateLayerPath(layer, stroke: s)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tool == .pen else { return }
        guard let s = currentStroke else { return }

        strokes.append(s)
        currentStroke = nil
        currentLayer = nil
        onTouchEnded?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke = nil
        currentLayer = nil
        onTouchEnded?()
    }

    // MARK: - Eraser (tap delete whole stroke)

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        guard tool == .eraser else { return }
        let pView = gr.location(in: self)
        guard imageRectInView.width > 1, imageRectInView.height > 1 else { return }

        guard let hit = hitTestStroke(at: pView) else { return }

        // remove model
        strokes.removeAll { $0.id == hit.id }
        // remove layer
        if let layer = strokeLayers[hit.id] {
            layer.removeFromSuperlayer()
            strokeLayers[hit.id] = nil
        }
    }

    private func hitTestStroke(at pView: CGPoint) -> Stroke? {
        // начинаем с последнего (верхний)
        for s in strokes.reversed() {
            let path = bezierPathViewSpace(stroke: s)
            let cg = path.cgPath

            let lineWidth = s.widthN * min(imageRectInView.width, imageRectInView.height)
            let hitWidth = max(22, lineWidth + 18)
            let stroked = cg.copy(strokingWithWidth: hitWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)

            if stroked.contains(pView) {
                return s
            }
        }
        return nil
    }

    // MARK: - Path + layers

    private func makeLayer(for s: Stroke) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = s.color.withAlphaComponent(s.opacity).cgColor

        // ✅ lineWidth в view-space из widthN
        l.lineWidth = s.widthN * min(imageRectInView.width, imageRectInView.height)

        l.lineCap = .round
        l.lineJoin = .round
        return l
    }

    private func updateLayerPath(_ layer: CAShapeLayer, stroke: Stroke) {
        layer.lineWidth = stroke.widthN * min(imageRectInView.width, imageRectInView.height)
        layer.strokeColor = stroke.color.withAlphaComponent(stroke.opacity).cgColor
        layer.path = bezierPathViewSpace(stroke: stroke).cgPath
    }

    private func bezierPathViewSpace(stroke: Stroke) -> UIBezierPath {
        // normalized -> view
        let pts = stroke.points.map { fromNormalized($0) }
        return bezierPath(points: pts)
    }

    private func bezierPath(points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)

        if points.count == 1 {
            path.addLine(to: first)
            return path
        }

        // сглаживание (midpoint)
        for i in 1..<points.count {
            let prev = points[i - 1]
            let cur = points[i]
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            path.addQuadCurve(to: mid, controlPoint: prev)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }

    private func redrawAllLayers() {
        // перерисовать толщины/пути (например при смене imageRectInView)
        for s in strokes {
            if let layer = strokeLayers[s.id] {
                updateLayerPath(layer, stroke: s)
            } else {
                let layer = makeLayer(for: s)
                strokeLayers[s.id] = layer
                self.layer.addSublayer(layer)
                updateLayerPath(layer, stroke: s)
            }
        }
        // удалить лишние слои (если вдруг)
        let valid = Set(strokes.map { $0.id })
        for (id, layer) in strokeLayers where !valid.contains(id) {
            layer.removeFromSuperlayer()
            strokeLayers[id] = nil
        }
    }

    // MARK: - Normalized mapping

    private func toNormalized(_ pView: CGPoint) -> CGPoint {
        let x = (pView.x - imageRectInView.minX) / imageRectInView.width
        let y = (pView.y - imageRectInView.minY) / imageRectInView.height
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private func fromNormalized(_ pN: CGPoint) -> CGPoint {
        CGPoint(
            x: imageRectInView.minX + pN.x * imageRectInView.width,
            y: imageRectInView.minY + pN.y * imageRectInView.height
        )
    }

    // MARK: - Render result (✅ теперь корректно)

    func renderStrokesOver(fullImage: UIImage) -> UIImage {
        let base = fullImage.normalizedUp()
        let size = base.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))

            for s in strokes {
                let color = s.color.withAlphaComponent(s.opacity)
                color.setStroke()

                let path = UIBezierPath()

                let ptsPx = s.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                guard let first = ptsPx.first else { continue }
                path.move(to: first)
                for p in ptsPx.dropFirst() { path.addLine(to: p) }

                path.lineCapStyle = .round
                path.lineJoinStyle = .round

                let lw = s.widthN * min(size.width, size.height)
                path.lineWidth = lw

                path.stroke()
            }
        }
    }
}
