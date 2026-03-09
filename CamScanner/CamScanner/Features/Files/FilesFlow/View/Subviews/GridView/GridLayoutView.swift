import SwiftUI

struct GridLayoutView: View {
    let highlightedID: UUID?
    var model: [FilesGridItem]
    var shouldHideAllSettings: Bool = false
    var shouldHideSettings: Bool = false

    let onFolderClick: ((UUID) -> Void)?
    let onDocumentClick: ((UUID) -> Void)?
    let onFavouriteClick: ((UUID, Bool) -> Void?)
    let onMenuClick: ((UUID, CGRect) -> Void)?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 26),
        count: 3
    )

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(model) { item in
                    switch item {
                    case let .document(doc):
                        GridDocumentItemView(
                            item: doc,
                            highlightedID: highlightedID,
                            shouldHideAllSettings: shouldHideAllSettings,
                            shouldHideSettings: shouldHideSettings,
                            onDocumentClick: onDocumentClick,
                            onFavouriteClick: onFavouriteClick,
                            onMenuClick: onMenuClick
                        )
                        .id(doc.id)
                        .contentShape(Rectangle())
                    case let .folder(folder):
                        GridFolderItemView(
                            item: folder,
                            highlightedID: highlightedID,
                            shouldHideAllSettings: shouldHideAllSettings,
                            shouldHideSettings: shouldHideSettings,
                            onFolderClick: onFolderClick,
                            onMenuClick: onMenuClick
                        )
                        .id(folder.id)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, Constants.tabBarHeight)
        }
    }
}

struct GridDocumentItemView: View {
    let item: FileDocumentItem
    let highlightedID: UUID?
    let shouldHideAllSettings: Bool
    let shouldHideSettings: Bool

    let onDocumentClick: ((UUID) -> Void)?
    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?

    private let cardHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GridDocumentBackground(item: item)
                .frame(height: cardHeight)
                .overlay {
                    GridDocumentPreview(item: item)
                }
                .overlay(alignment: .top) {
                    if !shouldHideAllSettings {
                        header
                    }
                }
                .cornerRadius(8)
                .appBorderModifier(.border(.primary), radius: 8)
                .clipped()

            footer
        }
        .drawingGroup()
        .background(highlight)
        .onTapGesture {
            onDocumentClick?(item.id)
        }
    }

    private var header: some View {
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

            Spacer()

            if !shouldHideSettings {
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
        .padding([.top, .horizontal], 4)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Text(item.title)
                .appTextStyle(.meta)
                .foregroundStyle(.text(.primary))
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                .appTextStyle(.helperText)
                .foregroundStyle(.text(.secondary))
        }
    }

    private var highlight: some View {
        Color(
            UIColor(
                red: 52/255,
                green: 199/255,
                blue: 89/255,
                alpha: highlightedID == item.id ? 0.1 : 0
            )
        )
        .cornerRadius(8)
        .padding(-8)
        .animation(.easeIn, value: highlightedID == item.id)
    }
}

struct GridDocumentBackground: View {
    let item: FileDocumentItem

    var body: some View {
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
                                Color.black.opacity(0.12),
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
}

struct GridDocumentPreview: View {
    let item: FileDocumentItem

    var body: some View {
        if item.isLocked {
            GridDocumentLockSkeleton()
                .padding(.bottom, 14)
        } else {
            switch item.documentType {
            case .documents:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case .idCard, .driverLicense:
                VStack(spacing: 6) {
                    if let image = item.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 54, height: 34)
                            .scaledToFit()
                    }

                    if let image = item.secondThumbnail {
                        Image(uiImage: image)
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
}

struct GridDocumentLockSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack {
                Image(appIcon: .lock_fill)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                    .frame(width: 20, height: 20)
                    .padding(.leading, 12)
                    .padding(.bottom, 9)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                lockLine(67)
                lockLine(79)
                lockLine(71)
                lockLine(79)
                lockLine(58)
            }
            .padding(.leading, 14)
        }
    }

    private func lockLine(_ width: CGFloat) -> some View {
        Rectangle()
            .foregroundStyle(
                Color(
                    UIColor(
                        red: 209/255,
                        green: 214/255,
                        blue: 225/255,
                        alpha: 1
                    )
                )
            )
            .cornerRadius(2)
            .frame(width: width, height: 4.2)
    }
}

struct GridFolderItemView: View {
    let item: FileFolderItem
    let highlightedID: UUID?
    let shouldHideAllSettings: Bool
    let shouldHideSettings: Bool

    let onFolderClick: ((UUID) -> Void)?
    var onMenuClick: ((UUID, CGRect) -> Void)?

    private let cardHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 8) {
            Image(appIcon: .folder_image)
                .frame(height: cardHeight)
                .overlay {
                    GridFolderOverlay(item: item)
                }
                .overlay(alignment: .topLeading) {
                    if !(shouldHideSettings || shouldHideAllSettings) {
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
                }

            VStack(spacing: 0) {
                Text(item.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.primary))
                    .lineLimit(1)

                Text("\(item.documentsCount) Documents")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
            }
        }
        .padding(8)
        .background(highlight)
        .drawingGroup()
        .onTapGesture {
            onFolderClick?(item.id)
        }
    }

    private var highlight: some View {
        Color(
            UIColor(
                red: 52/255,
                green: 199/255,
                blue: 89/255,
                alpha: highlightedID == item.id ? 0.1 : 0
            )
        )
        .cornerRadius(8)
        .animation(.easeIn, value: highlightedID == item.id)
    }
}

struct GridFolderOverlay: View {
    let item: FileFolderItem

    var body: some View {
        if item.isLocked {
            Image(appIcon: .lock_image)
        } else {
            if !item.previewDocuments.isEmpty {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        if let first = item.previewDocuments[safe: 0] {
                            GridFolderPreviewCell(document: first)
                        }

                        if let second = item.previewDocuments[safe: 1] {
                            GridFolderPreviewCell(document: second)
                        }
                    }

                    HStack(spacing: 12) {
                        if let first = item.previewDocuments[safe: 2] {
                            GridFolderPreviewCell(document: first)
                        }
                        
                        if let second = item.previewDocuments[safe: 3] {
                            GridFolderPreviewCell(document: second)
                        }
                    }
                }
                .padding(.top, 30)
                .padding([.horizontal, .bottom], 12)
                .clipped()
            }
        }
    }
}

struct GridFolderPreviewCell: View {
    let document: FileDocumentItem

    var body: some View {
        Rectangle()
            .foregroundStyle(.bg(.surface))
            .cornerRadius(4)
            .overlay {
                GridFolderPreviewImage(document: document)
            }
            .frame(width: 35, height: 50)
    }
}

struct GridFolderPreviewImage: View {
    let document: FileDocumentItem

    var body: some View {
        if document.isLocked {
            GridFolderLockSkeleton()
                .padding(.bottom, 4.67)
        } else {
            switch document.documentType {
            case .documents:
                if let image = document.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            case .idCard, .driverLicense:
                VStack(spacing: 2) {
                    if let image = document.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 18, height: 11.3)
                            .scaledToFit()
                    }
                    if let image = document.secondThumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 18, height: 11.3)
                            .scaledToFit()
                    }
                }
            case .passport:
                if let image = document.thumbnail {
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
}

struct GridFolderLockSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack {
                Image(appIcon: .lock_fill)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                    .frame(width: 11.33, height: 11.76)
                    .padding(.leading, 4.56)
                    .padding(.bottom, 4.24)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2.33) {
                line(22.33)
                line(26.33)
                line(23.67)
                line(26.33)
                line(19.33)
            }
            .padding(.leading, 4.67)
        }
    }

    private func line(_ width: CGFloat) -> some View {
        Rectangle()
            .foregroundStyle(
                Color(
                    UIColor(
                        red: 209/255,
                        green: 214/255,
                        blue: 225/255,
                        alpha: 1
                    )
                )
            )
            .cornerRadius(2)
            .frame(width: width, height: 1.4)
    }
}
