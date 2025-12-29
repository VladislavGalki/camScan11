import SwiftUI

struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            Path { p in
                p.move(to: CGPoint(x: w/3, y: 0))
                p.addLine(to: CGPoint(x: w/3, y: h))
                p.move(to: CGPoint(x: 2*w/3, y: 0))
                p.addLine(to: CGPoint(x: 2*w/3, y: h))

                p.move(to: CGPoint(x: 0, y: h/3))
                p.addLine(to: CGPoint(x: w, y: h/3))
                p.move(to: CGPoint(x: 0, y: 2*h/3))
                p.addLine(to: CGPoint(x: w, y: 2*h/3))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}
