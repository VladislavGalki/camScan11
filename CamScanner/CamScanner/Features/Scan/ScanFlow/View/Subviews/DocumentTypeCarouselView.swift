import SwiftUI

struct DocumentTypeCarouselView: View {
    @ObservedObject var uiState: ScanUIStateStore

    // id текущего “центрального” элемента
    @State private var centeredID: DocumentType.ID?

    var body: some View {
        GeometryReader { geo in
            let peek: CGFloat = 100          // сколько видно соседнего элемента с каждой стороны
            let gap: CGFloat = 16         // расстояние между элементами
            let pageWidth = geo.size.width - 2*peek
            let sideInset = (geo.size.width - pageWidth) / 2

            ScrollView(.horizontal) {
                LazyHStack(spacing: gap) {
                    ForEach(uiState.selectedDocumentType) { item in
                        Text(item.title)
                            .font(.system(size: 15, weight: item.isSelected ? .semibold : .regular))
                            .foregroundStyle(item.isSelected ? Color.green : Color.white.opacity(0.8))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(width: pageWidth)
                            .background(
                                Capsule()
                                    .fill(item.isSelected ? Color.white.opacity(0.08) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { centeredID = item.id }
                            }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideInset)
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredID, anchor: .center)
            .onAppear {
                if let selected = uiState.selectedDocumentType.first(where: { $0.isSelected }) {
                    withAnimation {
                        centeredID = selected.id
                    }
                }
            }
            .onChange(of: centeredID) { _, newID in
                guard let newID,
                      let item = uiState.selectedDocumentType.first(where: { $0.id == newID }) else { return }

                if !item.isSelected {
                    uiState.toggleDocumentType(item)
                }
            }
        }
        .frame(height: 44)
    }
}
