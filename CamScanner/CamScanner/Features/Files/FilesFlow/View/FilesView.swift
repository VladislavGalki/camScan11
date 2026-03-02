import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBarView
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                }
            }
            .scrollIndicators(.never)
            .contentMargins(.top, 16, for: .scrollContent)
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.main))
            .frame(maxWidth: .infinity)
            .frame(height: 114)
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
                .padding(.vertical, 10)
            }
    }
}
