//

import SwiftUI

public struct ProgressiveBlurView: UIViewRepresentable, Equatable {
    public func makeUIView(context: Context) -> CustomBlurView {
        let view = CustomBlurView()
        view.backgroundColor = .clear
        return view
    }
    
    public func updateUIView(_ uiView: CustomBlurView, context: Context) {}
}

public class CustomBlurView: UIVisualEffectView {
    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            DispatchQueue.main.async {
                self.removeFilters()
            }
        }
        
        removeFilters()
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        removeFilters()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func removeFilters() {
        if let filterLayer = layer.sublayers?.first {
            filterLayer.filters = []
        }
    }
}
