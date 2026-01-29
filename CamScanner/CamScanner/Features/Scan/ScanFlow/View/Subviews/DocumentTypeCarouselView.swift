import SwiftUI

struct DocumentTypeCarouselView: View {
    @ObservedObject var store: ScanStore
    
    @State private var centeredID: DocumentTypeEnum.ID?
    @State private var itemWidths: [DocumentTypeEnum.ID: CGFloat] = [:]

    var body: some View {
        GeometryReader { geo in
            let containerW = geo.size.width
            let firstID = DocumentTypeEnum.allCases.first?.id
            let lastID  = DocumentTypeEnum.allCases.last?.id

            let firstW = firstID.flatMap { itemWidths[$0] } ?? 0
            let lastW  = lastID.flatMap { itemWidths[$0] } ?? 0

            let leadingInset  = max(0, (containerW - firstW) / 2)
            let trailingInset = max(0, (containerW - lastW) / 2)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(DocumentTypeEnum.allCases) { type in
                        let isSelected = (store.ui.selectedDocumentType == type)

                        Text(type.title)
                            .appTextStyle(.bodySecondary)
                            .foregroundStyle(
                                isSelected
                                ? .text(.onImmersive)
                                : .text(.onImmersiveMuted)
                            )
                            .padding(.vertical, 11)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 100, style: .continuous)
                                    .foregroundStyle(
                                        isSelected
                                        ? Color.bg(.controlImmersive)
                                        : Color.clear
                                    )
                            )
                            .background(
                                GeometryReader { p in
                                    Color.clear
                                        .preference(
                                            key: ItemWidthKey.self,
                                            value: [type.id: p.size.width]
                                        )
                                }
                            )
                            .id(type.id)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    centeredID = type.id
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .contentMargins(.leading, leadingInset, for: .scrollContent)
            .contentMargins(.trailing, trailingInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredID, anchor: .center)
            .onPreferenceChange(ItemWidthKey.self) { dict in
                itemWidths.merge(dict) { _, new in new }
            }
            .onChange(of: itemWidths.count) { _, _ in
                guard centeredID == nil else { return }
                if itemWidths.count == DocumentTypeEnum.allCases.count {
                    centeredID = store.ui.selectedDocumentType.id
                }
            }
            .onChange(of: centeredID) { _, newID in
                guard
                    let newID,
                    let type = DocumentTypeEnum.allCases.first(where: { $0.id == newID })
                else { return }

                if store.ui.selectedDocumentType != type {
                    store.ui.selectedDocumentType = type
                    store.ui.idCaptureSide = .front
                }
            }
            .onAppear {
                centeredID = store.ui.selectedDocumentType.id
            }
        }
        .frame(height: 42)
    }
}



private struct ItemWidthKey: PreferenceKey {
    static var defaultValue: [DocumentTypeEnum.ID: CGFloat] = [:]
    static func reduce(value: inout [DocumentTypeEnum.ID: CGFloat], nextValue: () -> [DocumentTypeEnum.ID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
