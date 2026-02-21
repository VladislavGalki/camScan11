import SwiftUI

struct CaptureShutterButton: View {
    @State private var isCountingDown = false
    @State private var countdownValue = 3
    @State private var progress: CGFloat = 0
    @State private var countdownTask: Task<Void, Never>?

    let shouldStartAutoShootCountdown: Bool
    let buttonDisabled: Bool
    let action: () -> Void

    private let size: CGFloat = 80

    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.bg(.controlImmersive))
                .appBorderModifier(
                    .border(.primaryImmersive),
                    width: 1,
                    radius: 100,
                    corners: .allCorners
                )

            Circle()
                .foregroundStyle(
                    .bg(.surface)
                    .opacity(buttonDisabled ? 0.3 : 1)
                )
                .padding(8)

            if isCountingDown {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.elements(.accent),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(countdownValue)")
                    .appTextStyle(.screenTitle)
                    .foregroundStyle(.text(.accent))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: size, height: size)
        .onTapGesture {
            guard !buttonDisabled && !isCountingDown else { return }
            cancelCountdown()
            action()
        }

        .onChange(of: shouldStartAutoShootCountdown) { _, value in
            value ? startCountdown() : cancelCountdown()
        }
        .onDisappear {
            cancelCountdown()
        }
    }
}

// MARK: Countdown logic

extension CaptureShutterButton {
    private func startCountdown() {
        guard countdownTask == nil else { return }

        isCountingDown = true
        countdownValue = 3
        progress = 0

        // плавная animation круга (GPU, без лагов)
        withAnimation(.linear(duration: 3)) {
            progress = 1
        }

        countdownTask = Task {
            for value in (1...3).reversed() {
                await MainActor.run {
                    countdownValue = value
                }

                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled { return }
            }

            await MainActor.run {
                cancelCountdown()
                action()
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        progress = 0
    }
}
