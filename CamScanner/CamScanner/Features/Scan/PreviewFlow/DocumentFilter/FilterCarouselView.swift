import SwiftUI

struct FilterCarouselView: View {
    let model: [ScanFilterPreviewModel]
    let onFilterSelected: (DocumentFilterType) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model) { filter in
                        filterItem(filter)
                        
                        if filter.id == .original {
                            RoundedRectangle(cornerRadius: 100, style: .continuous)
                                .foregroundStyle(.divider(.default))
                                .frame(width: 1, height: 64)
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .onChange(of: selectedFilterId) { _, id in
                guard let id else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(DocumentFilterType.original, anchor: .center)
                    }
                    return
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func filterItem(_ item: ScanFilterPreviewModel) -> some View {
        let isSelected = item.isSelected
        
        imageItem(item.previewImage)
            .overlay(alignment: .bottom) {
                Text(item.filter.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(isSelected ? .text(.primary) : .text(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Color.bg(.accentSubtle)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? .border(.detectionFrame) : .clear, lineWidth: 2)
            }
            .cornerRadius(8, corners: .allCorners)
            .onTapGesture {
                onFilterSelected(item.filter)
            }
    }
    
    @ViewBuilder
    private func imageItem(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 64)
        } else {
            Rectangle()
                .foregroundStyle(.bg(.main))
                .overlay(alignment: .top) {
                    ProgressView()
                        .foregroundStyle(.text(.secondary))
                        .padding(.top, 13)
                }
                .frame(width: 80, height: 64)
        }
    }
    
    private var selectedFilterId: DocumentFilterType? {
        model.first(where: { $0.isSelected })?.id
    }
}
