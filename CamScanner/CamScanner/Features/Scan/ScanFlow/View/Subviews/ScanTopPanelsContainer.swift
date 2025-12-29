import SwiftUI

struct ScanTopPanelsContainer: View {

    @Binding var panel: ScanTopPanel

    let flashMode: FlashMode
    let quality: QualityPreset
    let filter: ScanFilter

    let onSelectFlash: (FlashMode) -> Void
    let onSelectQuality: (QualityPreset) -> Void
    let onSelectFilter: (ScanFilter) -> Void

    @State private var flashHeight: CGFloat = 0
    @State private var qualityHeight: CGFloat = 0
    @State private var filtersHeight: CGFloat = 0

    private var currentPanelHeight: CGFloat {
        switch panel {
        case .flash: return flashHeight
        case .quality: return qualityHeight
        case .filters: return filtersHeight
        default: return 0
        }
    }

    var body: some View {
        let height = currentPanelHeight

        ZStack(alignment: .top) {

            FlashPanel(selected: flashMode, onSelect: onSelectFlash)
                .opacity(panel == .flash ? 1 : 0)
                .reportHeight { flashHeight = $0 }

            QualityPanel(selected: quality, onSelect: onSelectQuality)
                .opacity(panel == .quality ? 1 : 0)
                .reportHeight { qualityHeight = $0 }

            FiltersPanel(selected: filter, onSelect: onSelectFilter)
                .opacity(panel == .filters ? 1 : 0)
                .reportHeight { filtersHeight = $0 }
        }
        .frame(height: height, alignment: .top)
        .clipped()
        .background(Color.black)
        .offset(y: height == 0 ? -12 : 0)
        .opacity(height == 0 ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: panel)
    }
}
