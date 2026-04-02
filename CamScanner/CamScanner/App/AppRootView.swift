import SwiftUI

struct AppRootView: View {
    var body: some View {
        RootNavigationView(
            root: AppEntryView(),
            destinationBuilder: resolve
        )
    }

    private func resolve(_ route: any Route) -> AnyView {
        switch route {

        // MARK: - Home

        case let r as HomeRoute:
            switch r {
            case .openDocument(let id):
                return AnyView(
                    OpenDocumentView(inputModel: OpenDocumentInputModel(documentID: id))
                )
            }
            
        // MARK: - Files
            
        case let r as FilesRoute:
            switch r {
            case let .openFolder(inputModel, onFolderDeleted):
                return AnyView(
                    FolderView(inputModel: inputModel, onFolderDeleted: onFolderDeleted)
                )
            case let .openDocument(inputModel):
                return AnyView(
                    OpenDocumentView(inputModel: inputModel)
                )
            }
            
        // MARK: - Scan
            
        case let r as ScanFlowRoute:
            switch r {
            case .scan:
                return AnyView(ScanFlowContainerView())
            case let .importCropper(inputModel):
                return AnyView(ImportFlowContainerView(inputModel: inputModel))
            }
            
        // MARK: - OpenDocument
            
        case let r as OpenDocumentRoute:
            switch r {
            case let .scanCropper(inputModel, onFinish):
                return AnyView(
                    ScanCropperView(input: inputModel, onFinish: onFinish)
                )
            case let .addText(inputModel):
                return AnyView(
                    AddTextView(inputModel: inputModel)
                )
            case let .watermark(inputModel):
                return AnyView(
                    WatermarkView(inputModel: inputModel)
                )
            case let .erase(inputModel):
                return AnyView(
                    EraseView(inputModel: inputModel)
                )
            case let .share(inputModel):
                return AnyView(
                    ShareView(inputModel: inputModel)
                )
            case let .scanFlow(inputModel, onDismiss):
                return AnyView(
                    ScanFlowContainerView(inputModel: inputModel, onDismiss: onDismiss)
                )
            }

        // MARK: - Merge

        case let r as MergeRoute:
            switch r {
            case .selectDocuments:
                return AnyView(
                    MergeSelectView()
                )

            case .arrangeDocuments(let ids):
                return AnyView(
                    MergeArrangeView(inputIDs: ids)
                )
            }

        default:
            return AnyView(EmptyView())
        }
    }
}
