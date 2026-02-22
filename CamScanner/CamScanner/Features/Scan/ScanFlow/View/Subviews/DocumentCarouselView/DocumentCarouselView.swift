import SwiftUI
import UIKit

struct DocumentTypeCarouselView: View {
    @ObservedObject var store: ScanStore
    let shouldHideNonSelectedItems: Bool
    
    private let items: [DocumentTypeEnum] = Array(DocumentTypeEnum.allCases)

    var body: some View {
        DocumentCarouselViewRepresentable(
            modes: items.map { CameraMode(title: $0.title) },
            shouldHideNonSelectedItems: shouldHideNonSelectedItems,
            selectedIndex: Binding(
                get: { items.firstIndex(of: store.ui.selectedDocumentType) ?? 0 },
                set: { newIndex in
                    guard items.indices.contains(newIndex) else { return }
                    store.ui.selectedDocumentType = items[newIndex]
                }
            )
        )
        .frame(height: 42)
        .allowsHitTesting(!shouldHideNonSelectedItems)
    }
}

struct DocumentCarouselViewRepresentable: UIViewRepresentable {
    let modes: [CameraMode]
    let shouldHideNonSelectedItems: Bool
    @Binding var selectedIndex: Int
    
    var onChanged: ((Int) -> Void)? = nil

    func makeUIView(context: Context) -> CameraModePickerView {
        let view = CameraModePickerView(modes: modes)

        view.shouldHideNonSelectedItems = shouldHideNonSelectedItems
        view.onModeChanged = { idx in
            if selectedIndex != idx {
                selectedIndex = idx
            }
            
            onChanged?(idx)
        }

        view.setSelectedIndex(selectedIndex, animated: false)
        return view
    }

    func updateUIView(_ uiView: CameraModePickerView, context: Context) {
        if uiView.shouldHideNonSelectedItems != shouldHideNonSelectedItems {
            uiView.shouldHideNonSelectedItems = shouldHideNonSelectedItems
            uiView.reloadVisibleCells()
        }
        
        if context.coordinator.lastTitles != modes.map(\.title) {
            uiView.setModes(modes)
            context.coordinator.lastTitles = modes.map(\.title)
        }

        if context.coordinator.lastSelected != selectedIndex {
            uiView.setSelectedIndex(selectedIndex, animated: true)
            context.coordinator.lastSelected = selectedIndex
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastSelected: Int = -1
        var lastTitles: [String] = []
    }
}
