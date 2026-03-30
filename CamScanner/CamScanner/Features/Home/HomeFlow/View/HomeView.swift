import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    
    @EnvironmentObject private var router: Router
    
    @State private var deleteCandidate: DocumentListItem? = nil
    @State private var showDeleteAlert: Bool = false
    
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
                                if !item.isLocked {
                                    router.push(HomeRoute.openDocument(id: item.id))
                                }
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
        .fullScreenCover(isPresented: $showAddCandidate) {
            OpenCVFilterDebugView()
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
                        router.push(HomeRoute.openDocument(id: id))
                        vm.clearSearch()
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
