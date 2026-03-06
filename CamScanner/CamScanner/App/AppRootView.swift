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
                    DocumentPreviewEntryView(documentID: id)
                )
            }
            
        // MARK: - Files
            
        case let r as FilesRoute:
            switch r {
            case let .openFolder(inputModel, onFolderDeleted):
                return AnyView(
                    FolderView(inputModel: inputModel, onFolderDeleted: onFolderDeleted)
                )
            }
            
        // MARK: - Scan
            
        case let r as ScanFlowRoute:
            switch r {
            case .scan:
                return AnyView(ScanFlowContainerView())
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
