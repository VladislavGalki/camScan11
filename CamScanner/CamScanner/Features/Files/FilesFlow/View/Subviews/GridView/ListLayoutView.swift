import SwiftUI

struct ListLayoutView: View {
    let highlightedID: UUID?
    var model: [FilesGridItem]
    var shouldHideAllSettings: Bool = false
    var shouldHideSettings: Bool = false

    let onFolderClick: ((UUID) -> Void)?
    let onDocumentClick: ((UUID) -> Void)?
    let onFavouriteClick: ((UUID, Bool) -> Void?)
    let onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.indices, id: \.self) { index in
                    ListItemRow(
                        item: model[index],
                        highlightedID: highlightedID,
                        shouldHideAllSettings: shouldHideAllSettings,
                        shouldHideSettings: shouldHideSettings,
                        onFolderClick: onFolderClick,
                        onDocumentClick: onDocumentClick,
                        onFavouriteClick: onFavouriteClick,
                        onMenuClick: onMenuClick
                    )

                    if index < model.count - 1 {
                        divider
                    }
                }
            }
            .padding(.top, 7)
            .padding(.horizontal, 16)
            .padding(.bottom, Constants.tabBarHeight)
        }
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 2)
            .foregroundStyle(.divider(.default))
            .frame(height: 1)
    }
}

struct ListItemRow: View {
    let item: FilesGridItem
    let highlightedID: UUID?
    let shouldHideAllSettings: Bool
    let shouldHideSettings: Bool

    let onFolderClick: ((UUID) -> Void)?
    let onDocumentClick: ((UUID) -> Void)?
    let onFavouriteClick: ((UUID, Bool) -> Void?)
    let onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        switch item {
        case let .document(document):
            ListDocumentRow(
                item: document,
                highlightedID: highlightedID,
                shouldHideAllSettings: shouldHideAllSettings,
                shouldHideSettings: shouldHideSettings,
                onFavouriteClick: onFavouriteClick,
                onMenuClick: onMenuClick
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onDocumentClick?(document.id)
            }
        case let .folder(folder):
            ListFolderRow(
                item: folder,
                highlightedID: highlightedID,
                shouldHideAllSettings: shouldHideAllSettings,
                shouldHideSettings: shouldHideSettings,
                onMenuClick: onMenuClick
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onFolderClick?(folder.id)
            }
        }
    }
}

struct ListDocumentRow: View {
    let item: FileDocumentItem
    let highlightedID: UUID?
    let shouldHideAllSettings: Bool
    let shouldHideSettings: Bool

    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            ListDocumentBackground(item: item)
                .frame(width: 35.33, height: 50)
                .appBorderModifier(.border(.primary), radius: 4)
                .overlay {
                    ListDocumentPreview(item: item)
                }
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.primary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)

            Spacer()

            HStack(spacing: 12) {
                if !shouldHideAllSettings {
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
            }
        }
        .padding(.vertical, 9)
        .background(highlight)
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
        .padding(.horizontal, -16)
        .animation(.easeIn, value: highlightedID == item.id)
    }
}

struct ListDocumentBackground: View {
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
}

struct ListDocumentPreview: View {
    let item: FileDocumentItem

    var body: some View {
        if item.isLocked {
            ListDocumentLock()
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
                    }

                    if let image = item.secondThumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 18, height: 11.33)
                    }
                }
            case .passport:
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 21.45, height: 29)
                }
            default:
                EmptyView()
            }
        }
    }
}

struct ListDocumentLock: View {
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
            .padding([.leading, .bottom], 4.67)
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

struct ListFolderRow: View {
    let item: FileFolderItem
    let highlightedID: UUID?
    let shouldHideAllSettings: Bool
    let shouldHideSettings: Bool

    var onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.documentsCount) Documents")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)

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
                }
                .frame(width: 28, height: 28)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(Rectangle())
        .padding(.vertical, 9)
        .background(highlight)
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
        .padding(.horizontal, -16)
        .animation(.easeIn, value: highlightedID == item.id)
    }
}
