import SwiftUI

struct DocumentTypeCarouselView: View {
    @ObservedObject var uiState: ScanUIStateStore
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 32) {
                ForEach(uiState.selectedDocumentType) { document in
                    Text(document.title)
                        .foregroundStyle(document.isSelected ? .green : .white)
                        .onTapGesture {
                            uiState.toggleDocumentType(document)
                        }
                }
            }
        }
    }
}
