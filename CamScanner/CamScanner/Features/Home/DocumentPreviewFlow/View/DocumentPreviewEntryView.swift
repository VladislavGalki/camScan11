import SwiftUI

struct DocumentPreviewEntryView: View {
    @StateObject private var vm = DocumentPreviewEntryViewModel()
    
    @EnvironmentObject private var router: Router
    
    let documentID: UUID

    var body: some View {
        ZStack {
            switch vm.state {
            case .loading:
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())

            case .error(let msg):
                Text(msg)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())

            case .scan(let pages, let remembered):
                ScanCameraPreviewView(
                    inputModel: ScanPreviewInputModel(
                        pages: pages,
                        previewMode: .existing(docID: documentID),
                        selectedFilterKey: remembered
                    ),
                    onDone: {
                        router.pop()
                    }
                )

            case .id(let result, let remembered):
                IdCameraPreviewView(
                    inputModel: IdPreviewInputModel(
                        result: result,
                        previewMode: .existing(docID: documentID),
                        selectedFilterKey: remembered
                    ),
                    onDone: {
                        router.pop()
                    }
                )
            }
        }
        .onAppear {
            vm.load(documentID: documentID)
        }
    }
}
