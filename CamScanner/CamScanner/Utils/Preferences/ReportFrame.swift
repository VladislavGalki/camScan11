import SwiftUI

struct ReportFrame: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let onChange: (CGRect) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: FramePreferenceKey.self,
                            value: proxy.frame(in: coordinateSpace)
                        )
                }
            )
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                onChange(frame)
            }
    }
}

extension View {
    func reportFrame(
        in coordinateSpace: CoordinateSpace = .global,
        onChange: @escaping (CGRect) -> Void
    ) -> some View {
        modifier(ReportFrame(coordinateSpace: coordinateSpace, onChange: onChange))
    }
}
