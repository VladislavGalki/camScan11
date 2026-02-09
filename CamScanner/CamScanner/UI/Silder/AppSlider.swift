import SwiftUI

struct AppSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 24
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = progress * (width - thumbSize)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .foregroundStyle(.bg(.accentSubtle))
                    .frame(height: trackHeight)
                
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .foregroundStyle(.bg(.accent))
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)
                
                Circle()
                    .foregroundStyle(.bg(.surface))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .foregroundStyle(.bg(.accent))
                            .frame(width: 12, height: 12)
                    )
                    .shadow(
                        color: .black.opacity(0.12),
                        radius: 4,
                        x: 0,
                        y: 0.5
                    )
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let x = min(max(0, gesture.location.x), width)
                                let newProgress = x / width
                                value = range.lowerBound +
                                newProgress * (range.upperBound - range.lowerBound)
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}
