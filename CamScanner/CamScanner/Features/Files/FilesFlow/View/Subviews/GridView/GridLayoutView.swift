import SwiftUI

struct GridLayoutView: View {
    let highlightedID: UUID?
    var model: [FilesGridItem]
    
    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?
    
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 26),
        count: 3
    )
    
    private let cardHeight: CGFloat = 150
    
    var body: some View {
        contentView
    }
    
    private var contentView: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(model) { item in
                    fileGridItemView(item: item)
                }
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, Constants.tabBarHeight)
        }
    }
    
    @ViewBuilder
    private func fileGridItemView(item: FilesGridItem) -> some View {
        switch item {
        case let .document(fileDocumentItem):
            documentCardView(for: fileDocumentItem)
        case let .folder(fileFolderItem):
            folderCardView(for: fileFolderItem)
        }
    }
    
    private func documentCardView(for item: FileDocumentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            documentBackgroundView(for: item)
                .frame(height: cardHeight)
                .overlay {
                    documentCardImageView(for: item)
                }
                .overlay(alignment: .top) {
                    HStack(spacing: 0) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(item.isFavourite ? .starFill : .star),
                                style: .secondary,
                                size: .s,
                                extraTitleColor: item.isFavourite ? .elements(.warning) : .elements(.accent)
                            ),
                            action: {
                                onFavouriteClick(item.id, !item.isFavourite)
                            }
                        )
                        
                        Spacer(minLength: 0)
                        
                        GeometryReader { geo in
                            AppButton(
                                config: AppButtonConfig(
                                    content: .iconOnly(.dots),
                                    style: .secondary,
                                    size: .s
                                ),
                                action: {
                                    let frame = geo.frame(in: .named("filesCoordinateSpace"))
                                    onMenuClick?(item.id, frame)
                                }
                            )
                        }
                        .frame(width: 28, height: 28)
                    }
                    .padding([.top, .horizontal], 4)
                }
                .cornerRadius(8, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 8)
                .clipped()
            
            VStack(spacing: 0) {
                Text(item.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity)
                
                Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
            }
        }
        .background(
            Color(
                UIColor(
                    red: 52.0/255.0,
                    green: 199.0/255.0,
                    blue: 89.0/255.0,
                    alpha: highlightedID == item.id ? 0.1 : 0
                )
            )
            .cornerRadius(8, corners: .allCorners)
            .animation(.easeIn, value: highlightedID == item.id)
            .padding(-8)
        )
    }
    
    @ViewBuilder
    private func documentBackgroundView(for item: FileDocumentItem) -> some View {
        if item.isLocked {
            Rectangle()
                .foregroundStyle(.bg(.surface))
        } else {
            switch item.documentType {
            case .documents:
                Rectangle()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.02),
                                Color.black.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            case .idCard, .passport, .driverLicense:
                Rectangle()
                    .foregroundStyle(.bg(.surface))
            default:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func documentCardImageView(for item: FileDocumentItem) -> some View {
        if item.isLocked {
            documentLockItemView
                .padding(.bottom, 14)
        } else {
            switch item.documentType {
            case .documents:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            case .idCard, .driverLicense:
                VStack(spacing: 6) {
                    if let image = item.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 54, height: 34)
                            .scaledToFit()
                    }
                    
                    if let secondImage = item.secondThumbnail {
                        Image(uiImage: secondImage)
                            .resizable()
                            .frame(width: 54, height: 34)
                            .scaledToFit()
                    }
                }
            case .passport:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 64, height: 87)
                        .scaledToFit()
                }
            default:
                EmptyView()
            }
        }
    }
    
    private var documentLockItemView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            
            HStack(spacing: 0) {
                Image(appIcon: .lock_fill)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                    .frame(width: 20, height: 20)
                    .padding(.leading, 12)
                    .padding(.bottom, 9)
                
                Spacer(minLength: 0)
            }
            
            VStack(alignment: .leading, spacing: 7) {
                documentLockLineView
                    .frame(width: 67, height: 4.2)
                
                documentLockLineView
                    .frame(width: 79, height: 4.2)
                
                documentLockLineView
                    .frame(width: 71, height: 4.2)
                
                documentLockLineView
                    .frame(width: 79, height: 4.2)
                
                documentLockLineView
                    .frame(width: 58, height: 4.2)
            }
            .padding(.leading, 14)
        }
    }
    
    private var documentLockLineView: some View {
        Rectangle()
            .foregroundStyle(
                Color(
                    UIColor(
                        red: 209.0 / 255.0,
                        green: 214.0 / 255.0,
                        blue: 225.0 / 255.0,
                        alpha: 1.0
                    )
                )
            )
            .cornerRadius(2, corners: .allCorners)
    }
    
    private func folderCardView(for item: FileFolderItem) -> some View {
        VStack(spacing: 8) {
            Image(appIcon: .folder_image)
                .frame(height: cardHeight)
                .overlay {
                    folderOverlayView(for: item)
                }
                .overlay(alignment: .topLeading) {
                    GeometryReader { geo in
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.dots),
                                style: .secondary,
                                size: .s
                            ),
                            action: {
                                let frame = geo.frame(in: .named("filesCoordinateSpace"))
                                onMenuClick?(item.id, frame)
                            }
                        )
                        .padding(4)
                    }
                    .frame(width: 28, height: 28)
                }
            
            VStack(spacing: 0) {
                Text(item.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            
                    Text("\(item.documentsCount) Documents")
                        .appTextStyle(.helperText)
                        .foregroundStyle(.text(.secondary))
            }
        }
        .padding(8)
        .background(
            Color(
                UIColor(
                    red: 52.0/255.0,
                    green: 199.0/255.0,
                    blue: 89.0/255.0,
                    alpha: highlightedID == item.id ? 0.1 : 0
                )
            )
            .cornerRadius(8, corners: .allCorners)
            .animation(.easeIn, value: highlightedID == item.id)
        )
    }
    
    @ViewBuilder
    private func folderOverlayView(for item: FileFolderItem) -> some View {
        if item.isLocked {
            Image(appIcon: .lock_image)
        } else {
            if !item.previewDocuments.isEmpty {
                GeometryReader { geo in
                    let size = geo.size.width / 2
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            if let firstDocument = item.previewDocuments[safe: 0] {
                                folderOverlayImageView(for: firstDocument, size: size)
                            }
                            if let secondDocument = item.previewDocuments[safe: 1] {
                                folderOverlayImageView(for: secondDocument, size: size)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            if let firstDocument = item.previewDocuments[safe: 2] {
                                folderOverlayImageView(for: firstDocument, size: size)
                            }
                            if let secondDocument = item.previewDocuments[safe: 3] {
                                folderOverlayImageView(for: secondDocument, size: size)
                            }
                        }
                    }
                    .padding(.top, 30)
                    .padding([.horizontal, .bottom], 12)
                }
                .clipped()
            }
        }
    }
    
    private func folderOverlayImageView(for document: FileDocumentItem, size: CGFloat) -> some View {
        documentBackgroundView(for: document)
            .cornerRadius(4, corners: .allCorners)
            .overlay {
                foldertCardImageView(for: document)
            }
    }
    
    @ViewBuilder
    private func foldertCardImageView(for item: FileDocumentItem) -> some View {
        if item.isLocked {
            foldertLockItemView
                .padding(.bottom, 4.67)
        } else {
            switch item.documentType {
            case .documents:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case .idCard, .driverLicense:
                VStack(spacing: 2) {
                    if let image = item.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 18, height: 11.3)
                            .scaledToFit()
                    }
                    
                    if let secondImage = item.secondThumbnail {
                        Image(uiImage: secondImage)
                            .resizable()
                            .frame(width: 18, height: 11.3)
                            .scaledToFit()
                    }
                }
            case .passport:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 21, height: 29)
                        .scaledToFit()
                }
            default:
                EmptyView()
            }
        }
    }
    
    private var foldertLockItemView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            
            HStack(spacing: 0) {
                Image(appIcon: .lock_fill)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                    .frame(width: 11.33, height: 11.76)
                    .padding(.leading, 4.56)
                    .padding(.bottom, 4.24)
                
                Spacer(minLength: 0)
            }
            
            VStack(alignment: .leading, spacing: 2.33) {
                documentLockLineView
                    .frame(width: 22.33, height: 1.4)
                
                documentLockLineView
                    .frame(width: 26.33, height: 1.4)
                
                documentLockLineView
                    .frame(width: 23.67, height: 1.4)
                
                documentLockLineView
                    .frame(width: 26.33, height: 1.4)
                
                documentLockLineView
                    .frame(width: 19.33, height: 1.4)
            }
            .padding(.leading, 4.67)
        }
    }
}
