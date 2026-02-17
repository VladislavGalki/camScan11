import SwiftUI

struct ShareView: View {
    @StateObject private var viewModel: ShareViewModel
    @EnvironmentObject private var router: Router
    
    init(inputModel: ShareInputModel) {
        _viewModel = StateObject(wrappedValue: ShareViewModel(inputModel: inputModel))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    documentFormatView
                        .padding(.bottom, 24)
                    
                    formatOptionView
                        .padding([.bottom, .horizontal], 16)
                    
                }
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
            .scrollIndicators(.never)
            .safeAreaInset(edge: .top, spacing: 0) {
                navigationView
            }
            .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                bottomContainerView
                    .padding(.horizontal, 16)
            }
        }
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
    }
    
    private var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: { router.dismissPresented() }
            )
            
            Text("Jun 30, 2026 Doc")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .underline(true, color: .text(.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 42, height: 42)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.5),
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var documentFormatView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select format")
                .appTextStyle(.sectionTitle)
                .foregroundStyle(.text(.primary))
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(viewModel.formatDocumentModel) { document in
                        VStack(spacing: 0) {
                            Image(appIcon: document.image)
                                .overlay(alignment: .bottom) {
                                    if document.isSelected {
                                        RoundedRectangle(cornerRadius: 100, style: .continuous)
                                            .foregroundStyle(.border(.accent))
                                            .frame(width: 47, height: 4)
                                            .offset(y: 2)
                                    }
                                }
                            
                            Spacer(minLength: 2)
                        }
                        .onTapGesture {
                            viewModel.selectFormatDocument(document)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var formatOptionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectedFormatDocument?.type == .pdf{
                HStack(spacing: 0) {
                    Text("Split PDF into Pages")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.secondary))
                    
                    Spacer(minLength: 0)
                    
                    Toggle("", isOn: $viewModel.isNeedSplitDocument)
                        .labelsHidden()
                        .tint(.bg(.accent))
                }
                .padding(.vertical, 15)
            }
            
            HStack(spacing: 0) {
                Text("Create ZIP Archive")
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.secondary))
                
                Spacer(minLength: 0)
                
                Toggle("", isOn: $viewModel.isNeetCreateZipArchve)
                    .labelsHidden()
                    .tint(.bg(.accent))
            }
            .padding(.vertical, 15)
            
            if viewModel.selectedFormatDocument?.type == .pdf{
                HStack(spacing: 0) {
                    Text("Set Password")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.secondary))
                    
                    Spacer(minLength: 0)
                    
                    Toggle("", isOn: $viewModel.isNeedSetPassword)
                        .labelsHidden()
                        .tint(.bg(.accent))
                }
                .padding(.vertical, 15)
            }
        }
    }
    
    private var bottomContainerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilesToShareProgressView(remaining: 5)
                .padding(.bottom, 12)
            
            AppButton(
                config: AppButtonConfig(
                    content: .title("Share"),
                    style: .primary,
                    size: .l,
                    isFullWidth: true
                ),
                action: {
                    
                }
            )
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0),
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.07),
                    Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
