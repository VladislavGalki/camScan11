import SwiftUI

struct UnlockQueueItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isLocked: Bool
}

@MainActor
final class MultipleUnlockPinViewModel: ObservableObject {
    @Published private(set) var items: [UnlockQueueItem]
    @Published private(set) var current: UnlockQueueItem?

    private(set) var unlockedIDs: [UUID] = []

    let validatePin: (UUID, String) -> Bool
    let onFinished: ([UUID]) -> Void

    init(
        items: [UnlockQueueItem],
        validatePin: @escaping (UUID, String) -> Bool,
        onFinished: @escaping ([UUID]) -> Void
    ) {
        self.items = items
        self.validatePin = validatePin
        self.onFinished = onFinished

        prepareInitialState()
    }

    // MARK: - Public

    func submit(pin: String) -> Bool {
        guard let current else { return false }

        if validatePin(current.id, pin) {
            unlockedIDs.append(current.id)
            moveNext()

            return true
        }

        return false
    }

    func skip() {
        moveNext()
    }

    // MARK: - Private

    private func prepareInitialState() {
        while let first = items.first, first.isLocked == false {
            unlockedIDs.append(first.id)
            items.removeFirst()
        }

        current = items.first

        if current == nil {
            finish()
        }
    }

    private func moveNext() {
        guard !items.isEmpty else {
            finish()
            return
        }

        items.removeFirst()

        while let first = items.first, first.isLocked == false {
            unlockedIDs.append(first.id)
            items.removeFirst()
        }

        if let next = items.first {
            current = next
        } else {
            finish()
        }
    }

    private func finish() {
        onFinished(unlockedIDs)
    }
}

struct MultipleUnlockPinView: View {
    @StateObject var viewModel: MultipleUnlockPinViewModel

    @State private var pin: String = ""
    @State private var triggerShake = false

    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            titleView
            
            subtitleView
                .padding(.bottom, 24)
            
            pinInputView
                .padding(.bottom, 24)
            
            skipButton
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
        Text("The PIN is required for \(viewModel.current?.title ?? "")")
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.secondary))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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
    
    private var skipButton: some View {
        AppButton(
            config: AppButtonConfig(
                content: .title("Skip"),
                style: .secondary,
                size: .l,
                isFullWidth: true
            ),
            action: {
                pin = ""
                viewModel.skip()
            }
        )
    }
    
    private func submitPin() {
        guard let current = viewModel.current else { return }

        if viewModel.submit(pin: pin) {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            pin = ""
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
