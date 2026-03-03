import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    
    var body: some View {
        contentView
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewState {
        case .empty:
            emptyView
        case .success:
            successView
        case .search:
            EmptyView()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(appIcon: .filesEmpty_image)
            
            Text("No Files Yet")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var successView: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBarView
            
            switch viewModel.gridLayout {
            case .grid:
                gridLayoutView
            case .list:
                listLayoutView
            }
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)
    }
    
    private var gridLayoutView: some View {
        GridLayoutView(model: viewModel.items)
    }
    
    private var listLayoutView: some View {
        ListLayoutView(model: viewModel.items)
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.main))
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Files")
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
                            action: {}
                        )
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.dots),
                                style: .secondary,
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
}
