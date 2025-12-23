import SwiftUI

struct ReportFrame: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        )
    }
}

extension View {
    func reportFrame() -> some View { modifier(ReportFrame()) }
}
