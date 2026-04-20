import SwiftUI

struct AppRootView: View {
    @Environment(\.dependencies) private var dependencies

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
                    OpenDocumentView(
                        inputModel: OpenDocumentInputModel(documentID: id),
                        dependencies: dependencies
                    )
                )
            }
            
        // MARK: - Files
            
        case let r as FilesRoute:
            switch r {
            case let .openFolder(inputModel, onFolderDeleted):
                return AnyView(
                    FolderView(
                        inputModel: inputModel,
                        onFolderDeleted: onFolderDeleted,
                        dependencies: dependencies
                    )
                )
            case let .openDocument(inputModel):
                return AnyView(
                    OpenDocumentView(inputModel: inputModel, dependencies: dependencies)
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
                    ScanCropperView(input: inputModel, onFinish: onFinish, dependencies: dependencies)
                )
            case let .addText(inputModel):
                return AnyView(
                    AddTextView(inputModel: inputModel, dependencies: dependencies)
                )
            case let .watermark(inputModel):
                return AnyView(
                    WatermarkView(inputModel: inputModel, dependencies: dependencies)
                )
            case let .erase(inputModel):
                return AnyView(
                    EraseView(inputModel: inputModel, dependencies: dependencies)
                )
            case let .share(inputModel):
                return AnyView(
                    ShareView(inputModel: inputModel, dependencies: dependencies)
                )
            case let .scanFlow(inputModel, onDismiss):
                return AnyView(
                    ScanFlowContainerView(inputModel: inputModel, onDismiss: onDismiss)
                )
            case let .selectPages(inputModel):
                return AnyView(
                    OpenDocumentSelectPagesView(inputModel: inputModel, dependencies: dependencies)
                )
            case let .createSignature(onSaved):
                return AnyView(
                    CreateSignatureView(onSaved: onSaved, dependencies: dependencies)
                        .presentationDetents([.large])
                        .presentationCornerRadius(38)
                        .interactiveDismissDisabled()
                )
            case let .placeSignature(inputModel):
                return AnyView(
                    PlaceSignatureView(inputModel: inputModel, dependencies: dependencies)
                )
            }

        default:
            return AnyView(EmptyView())
        }
    }
}
