import SwiftUI
import UIKit

struct BubbleOverlayHost<Content: View>: UIViewRepresentable {
    let frame: CGRect
    let content: Content

    init(
        frame: CGRect,
        @ViewBuilder content: () -> Content
    ) {
        self.frame = frame
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PassthroughView {
        let container = PassthroughView()

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.frame = frame

        context.coordinator.hostingController = hosting
        container.addSubview(hosting.view)

        return container
    }

    func updateUIView(_ uiView: PassthroughView, context: Context) {
        guard let hostingView = context.coordinator.hostingController?.view else { return }

        context.coordinator.hostingController?.rootView = content
        hostingView.frame = frame
    }

    final class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}
