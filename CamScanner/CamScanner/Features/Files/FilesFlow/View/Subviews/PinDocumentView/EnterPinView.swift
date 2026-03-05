import SwiftUI

struct EnterPinView: View {
    @State private var pin: String = ""
    @State private var triggerShake = false

    @FocusState private var focused: Bool

    let documentTitle: String
    let validatePin: (String) -> Bool
    let onSuccess: (() -> Void)?
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {

            titleView

            subtitleView
                .padding(.bottom, 24)

            pinInputView
                .padding(.bottom, 24)

            cancelButton
        }
        .padding(16)
        .frame(width: 300)
        .background(
            Color.bg(.surface)
                .cornerRadius(24)
        )
        .keyframeAnimator(initialValue: 0, trigger: triggerShake) { view, value in
            view.offset(x: value)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(-10, duration: 0.05)
                CubicKeyframe(10, duration: 0.05)
                CubicKeyframe(-8, duration: 0.05)
                CubicKeyframe(8, duration: 0.05)
                CubicKeyframe(0, duration: 0.05)
            }
        }
        .onAppear {
            focused = true
        }
    }
    
    private var titleView: some View {
        Text("Enter PIN to continue")
            .appTextStyle(.itemTitle)
            .foregroundStyle(.text(.primary))
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }
    
    private var subtitleView: some View {
        Text("The PIN is required for \(documentTitle)")
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.secondary))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var pinInputView: some View {
        ZStack {
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    if index < pin.count {
                        Circle()
                            .foregroundStyle(.bg(.accent))
                            .frame(width: 14, height: 14)
                    } else {
                        Circle()
                            .foregroundStyle(.bg(.controlOnSurface))
                            .appBorderModifier(.border(.accentSubtle), radius: 100)
                            .frame(width: 14, height: 14)
                    }
                }
            }

            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0)
                .onChange(of: pin) { _, newValue in
                    if newValue.count > 4 {
                        pin = String(newValue.prefix(4))
                    }

                    if pin.count == 4 {
                        submitPin()
                    }
                }
        }
    }
    
    private var cancelButton: some View {
        AppButton(
            config: AppButtonConfig(
                content: .title("Cancel"),
                style: .secondary,
                size: .l,
                isFullWidth: true
            ),
            action: {
                focused = false
                onClose?()
            }
        )
    }
    
    private func submitPin() {
        if validatePin(pin) {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            onSuccess?()
        } else {
            wrongPin()
        }
    }
    
    private func wrongPin() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.error)

        pin = ""
        triggerShake.toggle()
    }
}
