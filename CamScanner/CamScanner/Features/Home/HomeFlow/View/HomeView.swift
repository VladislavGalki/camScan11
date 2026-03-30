import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    
    @EnvironmentObject private var router: Router
    
    @State private var deleteCandidate: DocumentListItem? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var pinDocumentID: UUID?
    
    @State var showAddCandidate: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isSearchActive {
                searchView
            } else {
                navigationBarView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !vm.recentModel.isEmpty {
                            RecentView(model: vm.recentModel) {
                                router.present(ScanFlowRoute.scan)
                            } onDocumentTapped: { item in
                                vm.openDocumentTapped(id: item.id)
                            } onFavoriteTapped: { documentId, isFavorite in
                                vm.handleDocumentFavourite(documentId: documentId, isFavourite: isFavorite)
                            }
                            .padding(.bottom, 26)
                        }
                        
                        ExploreToolsView(model: vm.exploreToolModel) {
                            // all click
                        } onToolTapped: { toolType in
                            showAddCandidate = true
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .scrollIndicators(.never)
                .contentMargins(.top, 26, for: .scrollContent)
                .contentMargins(.bottom, Constants.tabBarHeight, for: .scrollContent)
            }
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)
        .overlay { pinOverlay }
        .fullScreenCover(isPresented: $showAddCandidate) {
            OpenCVFilterDebugView()
        }
        .onChange(of: vm.documentToOpen) { _, newValue in
            guard let newValue else { return }
            router.push(HomeRoute.openDocument(id: newValue))
            if vm.isSearchActive {
                vm.clearSearch()
            }
            vm.documentToOpen = nil
        }
        .onChange(of: vm.pinDocumentIDToOpen) { _, newValue in
            pinDocumentID = newValue
        }
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.surface))
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
            .appBorderModifier(.border(.primary), radius: 32, corners: [.bottomLeft, .bottomRight])
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Home")
                        .appTextStyle(.screenTitle)
                        .foregroundStyle(.text(.primary))
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 8) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.search),
                                style: .secondary,
                                size: .m
                            ),
                            action: {
                                vm.startSearch()
                            }
                        )
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .titleWithIcon(
                                    title: "Get PRO",
                                    icon: .starFill
                                ),
                                style: .primary,
                                size: .m
                            ),
                            action: {}
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            if vm.searchItems.isEmpty {
                FilesSearchEmptyView(
                    isSearching: !vm.searchText.isEmpty
                )
                .ignoresSafeArea(.keyboard)
            } else {
                HomeSearchResultsView(
                    items: vm.searchItems,
                    onDocumentClick: { id in
                        vm.openDocumentTapped(id: id)
                    },
                    onFavourite: { id, isFavourite in
                        vm.handleDocumentFavourite(documentId: id, isFavourite: isFavourite)
                    }
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            FilesSearchBarView(
                text: $vm.searchText,
                onClear: vm.clearSearch
            )
            .padding(16)
        }
    }

    @ViewBuilder
    private var pinOverlay: some View {
        if let pinDocumentID {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                EnterPinView(
                    documentTitle: vm.recentModel.first(where: { $0.id == pinDocumentID })?.title
                        ?? vm.searchItems.first(where: { $0.id == pinDocumentID })?.title
                        ?? "",
                    validatePin: { pin in
                        vm.validateDocumentPin(documentId: pinDocumentID, pin: pin)
                    },
                    onSuccess: {
                        vm.finishLockedDocumentOpen(documentId: pinDocumentID)

                        if vm.isSearchActive {
                            vm.clearSearch()
                        }

                        self.pinDocumentID = nil
                    },
                    onClose: {
                        vm.clearPendingPinRequest()
                        self.pinDocumentID = nil
                    }
                )
            }
        }
    }
}

private struct HomeSearchResultsView: View {
    let items: [FilesGridItem]
    let onDocumentClick: (UUID) -> Void
    let onFavourite: (UUID, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.bg(.main))
                .frame(height: 62)

            FilesLayoutContainer(
                mode: .list,
                items: items,
                highlightedID: nil,
                shouldHideSettings: true,
                onFolderClick: { _ in },
                onDocumentClick: onDocumentClick,
                onFavourite: onFavourite,
                onMenuClick: { _, _ in }
            )
        }
    }
}
