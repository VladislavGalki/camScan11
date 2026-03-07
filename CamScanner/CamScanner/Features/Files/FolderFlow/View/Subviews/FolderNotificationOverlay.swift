import SwiftUI

struct FolderNotificationOverlay: View {
    let state: FilesNotificationOverlayState
    let selectedMenuItem: FilesMenuItem?
    let viewModel: FolderViewModel
    
    let onClear: () -> Void
    
    var body: some View {
        if state != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                
                switch state {
                case let .deleteFile(id):
                    DeleteDocumentView(
                        onDelete: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: id,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                case let .unlockDocument(id):
                    UnlockDocumentView(
                        documentTitle: viewModel.getTitleForItem(id: id),
                        onRemove: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: id,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                case let .lock(id):
                    LockDocumentView {
                        await viewModel.handleFaceIdRequest()
                    } onSuccess: { pin, viaFaceId in
                        viewModel.hadleDocumentPinCreated(
                            documentId: id,
                            pin: pin,
                            viaFaceId: viaFaceId
                        )
                        
                        onClear()
                    } onClose: {
                        onClear()
                    }
                case let .unlock(id):
                    EnterPinView(
                        documentTitle: viewModel.getTitleForItem(id: id),
                        validatePin: { pin in
                            return viewModel.handleDocumentPinValidation(
                                documentId: id,
                                pin: pin
                            )
                        },
                        onSuccess: {
                            switch selectedMenuItem {
                            case .unlockDocument:
                                viewModel.notificationOverlaystate = .unlockDocument(id)
                            case .delete:
                                viewModel.notificationOverlaystate = .deleteFile(id)
                            case .share:
                                viewModel.folderActiveSheet = .share(id)
                                onClear()
                            default:
                                onClear()
                            }
                        },
                        onClose: {
                            onClear()
                        }
                    )
                case .none:
                    EmptyView()
                }
            }
        }
    }
}
