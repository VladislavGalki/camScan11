import SwiftUI

struct NotificationToast: View {
    @Binding var isPresented: Bool

    @State private var offsetY: CGFloat = -120
    @State private var dragOffsetY: CGFloat = 0
    @State private var workItem: DispatchWorkItem?

    let title: String
    private let duration: Double = 2.0

    var body: some View {
        HStack(spacing: 8) {
            Image(appIcon: .check_circle)
                .renderingMode(.template)
                .foregroundStyle(.elements(.onSuccess))

            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.onSuccess))
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.bg(.success)
                .cornerRadius(12, corners: .allCorners)
                .appBorderModifier(.border(.onSuccess), radius: 12)
        )
        .padding(.horizontal, 16)
        .offset(y: offsetY + min(dragOffsetY, 0))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffsetY = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        workItem?.cancel()
                        hide()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        dragOffsetY = 0
                    }
                }
        )
        .onChange(of: isPresented) { _, value in
            if value {
                show()
            }
        }
        .onAppear {
            if isPresented {
                show()
            }
        }
    }

    func show() {
        workItem?.cancel()
        dragOffsetY = 0

        withAnimation(
            .spring(response: 0.35, dampingFraction: 0.85)
        ) {
            offsetY = 28
        }

        let task = DispatchWorkItem {
            hide()
        }

        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    func hide() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            offsetY = -120
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}
