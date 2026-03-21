import SwiftUI

struct ShareView: View {
    @StateObject private var viewModel: ShareViewModel
    @EnvironmentObject private var router: Router
    
    private let onClose: (() -> Void)?
    
    init(inputModel: ShareInputModel, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: ShareViewModel(inputModel: inputModel))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    documentCollectionView
                        .padding(.bottom, 20)
                    
                    withoutWatermarkView
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    
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
            }
        }
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .sheet(item: $viewModel.shareActiveSheet) { sheet in
            switch sheet {
            case .renameFileSheet:
                RenameFileView(documentFileName: $viewModel.documentName)
                    .presentationCornerRadius(38)
            case .exportShareSheet:
                ShareSheetRepresentable(
                    urls: viewModel.shareSheetURLs
                ) { success in
                    if success {
                        viewModel.updateQoutaShareLimit()
                    }
                }
                .onDisappear {
                    viewModel.isLoading = false
                }
            case .setPasswordSheet:
                PasswordDocumentView(currentPassword: $viewModel.documentPassword)
                    .onDisappear {
                        if viewModel.documentPassword == nil {
                            viewModel.isNeedSetPassword = false
                        }
                    }
                    .presentationCornerRadius(38)
                    .interactiveDismissDisabled()
            }
        }
    }
    
    private var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    router.dismissSheet()
                    onClose?()
                }
            )
            
            Text(viewModel.documentName)
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .underline(true, color: .text(.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    viewModel.shareActiveSheet = .renameFileSheet
                }
            
            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 42, height: 42)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ProgressiveBlurView()
                .blur(radius: 20)
                .background {
                    LinearGradient(
                        colors: [
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.5),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
        )
    }
    
    @ViewBuilder
    private var documentCollectionView: some View {
        if viewModel.sharePreviewModel.count > 1 {
            scrollableDocumentCollectionView
        } else {
            if let firstDocument = viewModel.sharePreviewModel.first {
                VStack(spacing: 0) {
                    documentItemView(firstDocument)
                        .padding(.top, 16)
                }
            }
        }
    }
    
    private var scrollableDocumentCollectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("\(viewModel.countOfFilesToShare) selected")
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.secondary))
                
                Spacer(minLength: 0)
                
                Text("Deselect All")
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.accent))
                    .onTapGesture {
                        viewModel.deselectAllDocuments()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.sharePreviewModel) { document in
                            documentItemView(document)
                                .id(document.id)
                                .onTapGesture {
                                    viewModel.selectDocumentToShare(document)
                                    withAnimation {
                                        proxy.scrollTo(document.id, anchor: .center)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    @ViewBuilder
    private func documentItemView(_ document: SharePreviewModel) -> some View {
        Color.bg(.surface)
            .overlay {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        switch document.documentType {
                        case .documents:
                            if let image = document.frames.first?.preview {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .overlay {
                                        OpenDocumentTextOverlayView(items: document.textItems)
                                    }
                            }
                        case .idCard, .driverLicense:
                            VStack(spacing: 8) {
                                if let image = document.frames.first?.preview {
                                    Image(uiImage: image)
                                        .resizable()
                                        .frame(width: 85.5, height: 55)
                                        .scaledToFit()
                                        .overlay {
                                            OpenDocumentTextOverlayView(
                                                items: document.textItems.filter { $0.pageIndex == 0 }
                                            )
                                        }
                                }

                                if let secondImage = document.frames.last?.preview {
                                    Image(uiImage: secondImage)
                                        .resizable()
                                        .frame(width: 85.5, height: 55)
                                        .scaledToFit()
                                        .overlay {
                                            OpenDocumentTextOverlayView(
                                                items: document.textItems.filter { $0.pageIndex == 1 }
                                            )
                                        }
                                }
                            }
                        case .passport:
                            if let image = document.frames.first?.preview {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 88, height: 125)
                                    .scaledToFit()
                                    .overlay {
                                        OpenDocumentTextOverlayView(items: document.textItems)
                                    }
                            }
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                    
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(height: 28)
                }
                .opacity(document.isSelected ? 1 : 0.4)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.sharePreviewModel.count > 1 {
                    Image(appIcon: document.isSelected ? .check_image : .empty_check_image)
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Image(appIcon: .appMiniLogoImage)
                    
                    Text("SmartScan Ai")
                        .font(.system(size: 8, weight: .semibold, design: .default))
                        .lineSpacing(2)
                }
                .padding(3)
                .background(
                    Color.bg(.main)
                        .cornerRadius(4, corners: .allCorners)
                )
                .padding([.bottom, .horizontal], 8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: 150, height: 212)
            .appBorderModifier(.border(.primary), radius: 16)
            .cornerRadius(16, corners: .allCorners)
    }
    
    private var withoutWatermarkView: some View {
        HStack(spacing: 0) {
            Text("Export without watermark")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.bg(.accent))
            
            Spacer(minLength: 0)
            
            AppButton(
                config: AppButtonConfig(
                    content: .title("Get PRO"),
                    style: .primary,
                    size: .s
                ),
                action: {}
            )
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 44)
        .background(
            Color.bg(.accentSubtle)
                .cornerRadius(60, corners: .allCorners)
                .appBorderModifier(
                    Color(
                        uiColor: UIColor(red: 206/255, green: 220/255, blue: 255/255, alpha: 1)
                    ), radius: 60
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.sharePreviewModel.count > 1 {
                        Image(appIcon: .rect_separator_image)
                            .offset(x: 60, y: -13)
                    }
                }
                .overlay(alignment: .top) {
                    if viewModel.sharePreviewModel.count == 1 {
                        Image(appIcon: .rect_separator_image)
                            .offset(y: -13)
                    }
                }
        )
    }
    
    private var documentFormatView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select format")
                .appTextStyle(.sectionTitle)
                .foregroundStyle(.text(.primary))
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            
            ScrollViewReader { proxy in
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
                            .id(document.id)
                            .onTapGesture {
                                viewModel.selectFormatDocument(document)
                                withAnimation {
                                    proxy.scrollTo(document.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set Password")
                            .appTextStyle(.bodyPrimary)
                            .foregroundStyle(.text(.secondary))
                        
                        Text(viewModel.documentPassword ?? "Only for PDF files")
                            .appTextStyle(.helperText)
                            .foregroundStyle(.text(.secondary))
                    }
                    
                    Spacer(minLength: 0)
                    
                    Toggle("", isOn: $viewModel.isNeedSetPassword)
                        .labelsHidden()
                        .tint(.bg(.accent))
                        .onChange(of: viewModel.isNeedSetPassword) { _, newValue in
                            if newValue {
                                viewModel.shareActiveSheet = .setPasswordSheet
                            }
                        }
                }
                .padding(.vertical, 12)
            }
        }
    }
    
    private var bottomContainerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilesToShareProgressView(remaining: viewModel.qoutaLimit)
                .padding(.bottom, 12)
            
            AppButton(
                config: AppButtonConfig(
                    content: .title("Share"),
                    style: .primary,
                    size: .l,
                    isFullWidth: true
                ),
                action: {
                    viewModel.share()
                }
            )
            .appButtonEnabled(viewModel.qoutaLimit > 0)
            .appButtonIsLoading(viewModel.isLoading)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(
            ProgressiveBlurView()
                .blur(radius: 2)
                .padding(.horizontal, -32)
                .background() {
                    LinearGradient(
                        colors: [
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.0),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.7),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
        )
    }
}
