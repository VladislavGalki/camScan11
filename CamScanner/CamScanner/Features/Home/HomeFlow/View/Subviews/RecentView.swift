import SwiftUI

struct RecentView: View {
    let model: [RecentDocumentModel]
    let onPreviewTapped: () -> Void
    let onDocumentTapped: (RecentDocumentModel) -> Void
    
    private let itemSize = CGSize(width: 140, height: 182)
    
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
            }
            .frame(width: itemSize.width, height: itemSize.height)
            .cornerRadius(16, corners: .allCorners)
            .appBorderModifier(.border(.primary), radius: 16)
            .padding(.bottom, 34)
    }
    
    private func recentItemView(_ item: RecentDocumentModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                .frame(width: itemSize.width, height: itemSize.height)
                .overlay {
                    itemImageView(for: item)
                }
                .overlay(alignment: .top) {
                    HStack(spacing: 0) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.star),
                                style: .secondary,
                                size: .s
                            ),
                            action: {
                                
                            }
                        )
                        
                        Spacer(minLength: 0)
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.dots),
                                style: .secondary,
                                size: .s
                            ),
                            action: {
                                
                            }
                        )
                    }
                    .padding([.top, .horizontal], 8)
                }
                .cornerRadius(16, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 16)
                .clipped()
            
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.primary))
                
                Text(item.pageCount)
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
            }
            .padding(.leading, 4)
        }
    }
    
    @ViewBuilder
    private func itemImageView(for item: RecentDocumentModel) -> some View {
        switch item.kind {
        case .scan:
            if let image = item.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        case .id:
            VStack(spacing: 8) {
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 85.5, height: 55)
                        .scaledToFit()
                }
                
                if let secondImage = item.secondThumbnail {
                    Image(uiImage: secondImage)
                        .resizable()
                        .frame(width: 85.5, height: 55)
                        .scaledToFit()
                }
            }
        }
    }
}
