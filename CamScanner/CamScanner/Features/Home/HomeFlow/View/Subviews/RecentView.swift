import SwiftUI

struct RecentView: View {
    let model: [RecentDocumentModel]
    let onPreviewTapped: () -> Void
    let onDocumentTapped: (RecentDocumentModel) -> Void
    let onFavoriteTapped: (UUID, Bool) -> Void
    let onMenuClick: (UUID, CGRect) -> Void
    
    private let itemSize = CGSize(width: 106, height: 150)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    previewItemView
                        .onTapGesture {
                            onPreviewTapped()
                        }
                    
                    ForEach(model) { item in
                        recentItemView(item)
                            .onTapGesture {
                                onDocumentTapped(item)
                            }
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Recent")
                .appTextStyle(.sectionTitle)
                .foregroundStyle(.text(.primary))
            
            Spacer(minLength: 0)
            
            Button {
            } label: {
                HStack(spacing: 2) {
                    Text("See All")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.accent))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.text(.accent))
                }
            }
        }
    }
    
    private var previewItemView: some View {
        Rectangle()
            .foregroundStyle(.bg(.surface))
            .overlay {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.plus),
                        style: .secondary,
                        size: .l
                    ),
                    action: {}
                )
                .allowsHitTesting(false)
            }
            .frame(width: itemSize.width, height: itemSize.height)
            .cornerRadius(8, corners: .allCorners)
            .appBorderModifier(.border(.primary), radius: 8)
            .padding(.bottom, 34)
    }
    
    private func recentItemView(_ item: RecentDocumentModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            recentItemBackground(item)
                .frame(width: itemSize.width, height: itemSize.height)
                .overlay {
                    itemImageView(for: item)
                }
                .overlay(alignment: .top) {
                    HStack(spacing: 0) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(item.isFavorite ? .starFill : .star),
                                style: .secondary,
                                size: .s,
                                extraTitleColor: item.isFavorite ? .elements(.warning) : .elements(.accent)
                            ),
                            action: {
                                onFavoriteTapped(item.id, !item.isFavorite)
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
                                    let frame = geo.frame(in: .named("homeCoordinateSpace"))
                                    onMenuClick(item.id, frame)
                                }
                            )
                        }
                        .frame(width: 28, height: 28)
                    }
                    .padding([.top, .horizontal], 8)
                }
                .cornerRadius(8, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 8)
                .clipped()
            
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: itemSize.width, alignment: .leading)
                
                Text(item.pageCountText)
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .frame(width: itemSize.width, alignment: .leading)
            }
        }
    }
    
    @ViewBuilder
    private func itemImageView(for item: RecentDocumentModel) -> some View {
        if item.isLocked {
            GridDocumentLockSkeleton()
                .padding(.bottom, 14)
        } else {
            switch item.previewDocumentType {
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

    @ViewBuilder
    private func recentItemBackground(_ item: RecentDocumentModel) -> some View {
        if item.isLocked {
            Rectangle()
                .foregroundStyle(.bg(.surface))
        } else {
            switch item.previewDocumentType {
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
