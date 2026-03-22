import SwiftUI

struct ExtractSpinnerView: View {
    @State private var isAnimating = false

    private let size: CGFloat = 60
    private let lineWidth: CGFloat = 8
    private let backgroundColor = Color(hex: "CEDCFF") ?? .clear
    private let foregroundColor = Color.bg(.accent)

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(
                .linear(duration: 1)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}
