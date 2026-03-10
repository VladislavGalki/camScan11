import SwiftUI

struct FilesNotificationOverlay: View {
    let state: FilesNotificationOverlayState
    
    let selectedID: UUID?
    let selectedMenuItem: FilesMenuItem?
    
    let viewModel: FilesViewModel
    
    let onClear: () -> Void
    let onShowTabBar: () -> Void
    
    var body: some View {
        if state != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                
                switch state {
                case .deleteFile:
                    DeleteDocumentView(
                        onDelete: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedID,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                    .onDisappear {
                        onShowTabBar()
                    }
                case .unlockDocument:
                    UnlockDocumentView(
                        documentTitle: viewModel.getTitleForItem(id: selectedID),
                        onRemove: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedID,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                    .onDisappear {
                        onShowTabBar()
                    }
                case .lock:
                    LockDocumentView {
                        await viewModel.handleFaceIdRequest()
                    } onSuccess: { pin, viaFaceId in
                        viewModel.hadleDocumentPinCreated(
                            documentId: selectedID,
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
                            if let selectedMenuItem {
                                switch selectedMenuItem {
                                case .unlockDocument:
                                    viewModel.notificationOverlaystate = .unlockDocument(id)
                                case .delete:
                                    viewModel.notificationOverlaystate = .deleteFile(id)
                                case .share:
                                    onClear()
                                    onShowTabBar()
                                    viewModel.processSuccessMenuItemSelection(id: id, menuItem: selectedMenuItem)
                                default:
                                    onClear()
                                }
                            } else {
                                viewModel.executePendingAction()
                                onClear()
                            }
                        },
                        onClose: {
                            onShowTabBar()
                            onClear()
                        }
                    )
                case let .multipleUnlock(items):
                    MultipleUnlockPinView(
                        viewModel: MultipleUnlockPinViewModel(
                            items: items,
                            validatePin: { id, pin in
                                viewModel.handleDocumentPinValidation(
                                    documentId: id,
                                    pin: pin
                                )
                            },
                            onFinished: { unlockedIDs in
                                viewModel.handleMultipleUnlockAction(ids: unlockedIDs)
                                onClear()
                            }
                        )
                    )
                case .none:
                    EmptyView()
                }
            }
        }
    }
}
