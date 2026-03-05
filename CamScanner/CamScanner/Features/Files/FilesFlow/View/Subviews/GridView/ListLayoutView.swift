import SwiftUI

struct ListLayoutView: View {
    let highlightedID: UUID?
    var model: [FilesGridItem]

    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.indices, id: \.self) { index in
                    ListItemRow(
                        item: model[index],
                        highlightedID: highlightedID,
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

    var onFavouriteClick: ((UUID, Bool) -> Void?)
    var onMenuClick: ((UUID, CGRect) -> Void)?

    var body: some View {
        switch item {
        case let .document(document):
            ListDocumentRow(
                item: document,
                highlightedID: highlightedID,
                onFavouriteClick: onFavouriteClick,
                onMenuClick: onMenuClick
            )
        case let .folder(folder):
            ListFolderRow(
                item: folder,
                highlightedID: highlightedID,
                onMenuClick: onMenuClick
            )
        }
    }
}

struct ListDocumentRow: View {
    let item: FileDocumentItem
    let highlightedID: UUID?

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

                Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
            }
            .padding(.vertical, 7)

            Spacer()

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

struct ListFolderRow: View {
    let item: FileFolderItem
    let highlightedID: UUID?

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

                Text("\(item.documentsCount) Documents")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
            }
            .padding(.vertical, 7)

            Spacer()

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
