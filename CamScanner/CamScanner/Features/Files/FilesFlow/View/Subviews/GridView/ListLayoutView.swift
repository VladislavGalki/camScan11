import SwiftUI

struct ListLayoutView: View {
    let highlightedID: UUID?
    var model: [FilesGridItem]
    
    @State private var shouldShowMenu: Bool = false

    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        contentView
    }
    
    private var contentView: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.enumerated()), id: \.element.id) { index, item in
                    fileListItemView(item: item)

                    if index < model.count - 1 {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .foregroundStyle(.divider(.default))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 7)
            .padding(.horizontal, 16)
            .padding(.bottom, Constants.tabBarHeight)
        }
    }
    
    @ViewBuilder
    private func fileListItemView(item: FilesGridItem) -> some View {
        switch item {
        case let .document(fileDocumentItem):
            documentCardView(for: fileDocumentItem)
        case let .folder(fileFolderItem):
            folderCardView(for: fileFolderItem)
        }
    }
    
    private func documentCardView(for item: FileDocumentItem) -> some View {
        HStack(spacing: 10) {
            documentBackgroundView(for: item)
                .frame(width: 35.33, height: 50)
                .appBorderModifier(.border(.primary), radius: 4)
                .overlay {
                    documentCardImageView(for: item)
                }
                .cornerRadius(4, corners: .allCorners)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.primary))
                
                Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 7)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
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
        }
        .padding(.vertical, 9)
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
                .padding(.bottom, 4.67)
        } else {
            switch item.documentType {
            case .documents:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            case .idCard, .driverLicense:
                VStack(spacing: 2) {
                    if let image = item.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 18, height: 11.33)
                            .scaledToFit()
                    }
                    
                    if let secondImage = item.secondThumbnail {
                        Image(uiImage: secondImage)
                            .resizable()
                            .frame(width: 18, height: 11.33)
                            .scaledToFit()
                    }
                }
            case .passport:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 21.45, height: 29)
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
        HStack(spacing: 10) {
            Image(appIcon: .folder_small_image)
                .overlay {
                    if item.isLocked {
                        Image(appIcon: .lock_image)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.primary))
                
                Text("\(item.documentsCount) Documents)")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 7)
            
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
        .padding(.vertical, 9)
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
            .padding(.horizontal, -16)
            .animation(.easeIn, value: highlightedID == item.id)
        )
    }
}
