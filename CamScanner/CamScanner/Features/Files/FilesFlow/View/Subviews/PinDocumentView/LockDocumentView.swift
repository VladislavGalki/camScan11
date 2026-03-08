import SwiftUI

struct LockDocumentView: View {
    enum Step {
        case create
        case confirm
    }

    @State private var step: Step = .create
    @State private var pin: String = ""
    @State private var firstPin: String = ""
    @State private var useFaceId: Bool = false
    @State private var triggerShake = false

    @FocusState private var focused: Bool
    
    let faceIdRequest: (() async -> Bool)?
    let onSuccess: ((String, Bool) -> Void)?
    let onClose: (() -> Void?)

    var body: some View {
        VStack(spacing: 0) {
            Text(step == .create ? "Lock Document" : "Confirm PIN")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)
                .multilineTextAlignment(.center)

            Text("Use a PIN to lock this document in the app. Set a password in Share for exported files.")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            pinInputView
                .padding(.bottom, 24)

            faceIdToggleView
                .padding(.bottom, 24)

            buttonView
        }
        .padding(16)
        .frame(width: 300)
        .background(
            Color.bg(.surface)
                .cornerRadius(24, corners: .allCorners)
        )
        .offset(x: triggerShake ? -10 : 0)
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
    
    var pinInputView: some View {
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
                        handlePinEntered()
                    }
                }
        }
    }
    
    var faceIdToggleView: some View {
        HStack(spacing: 10) {
            Image(appIcon: .faceId_image)

            Text("Face ID")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))

            Toggle("", isOn: Binding(
                get: { useFaceId },
                set: { newValue in
                    if newValue {
                        Task {
                            useFaceId = await faceIdRequest?() ?? false
                        }
                    } else {
                        useFaceId = false
                    }
                }
            ))
            .labelsHidden()
            .tint(.bg(.accent))
        }
    }

    var buttonView: some View {
        AppButton(
            config: AppButtonConfig(
                content: .title("Cancel"),
                style: .secondary,
                size: .l,
                isFullWidth: true
            ),
            action: {
                focused = false
                onClose()
            }
        )
    }
    
    private func handlePinEntered() {
        if step == .create {
            firstPin = pin
            pin = ""
            step = .confirm
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            if firstPin == pin {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSuccess?(pin, useFaceId)
            } else {
                wrongPin()
            }
        }
    }

    func wrongPin() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        
        step = .create
        firstPin = ""
        pin = ""

        triggerShake.toggle()
    }
}
