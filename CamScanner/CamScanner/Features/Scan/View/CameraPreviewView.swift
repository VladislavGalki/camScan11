import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    private let quadLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.strokeColor = UIColor.systemGreen.cgColor
        l.fillColor = UIColor.clear.cgColor
        l.lineWidth = 2
        l.lineJoin = .round
        l.lineCap = .round
        l.opacity = 0
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(quadLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(quadLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        quadLayer.frame = bounds
    }

    func updateQuad(_ quad: [CGPoint]?) {
        guard let quad, quad.count == 4 else {
            quadLayer.opacity = 0
            quadLayer.path = nil
            return
        }

        // convert capture device points -> layer points (correct with aspectFill cropping)
        let pts = quad.map { videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }

        let path = UIBezierPath()
        path.move(to: pts[0])
        path.addLine(to: pts[1])
        path.addLine(to: pts[2])
        path.addLine(to: pts[3])
        path.close()

        quadLayer.path = path.cgPath
        quadLayer.opacity = 1
    }
}
