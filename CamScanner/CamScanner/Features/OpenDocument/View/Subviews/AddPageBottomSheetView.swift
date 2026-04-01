import SwiftUI

private enum ContainerType {
    case scan
    case importFromPhotos
    case importFromFiles
}

struct AddPageBottomSheetView: View {
    let onTapScan: () -> Void
    let onTapImportFromPhotos: () -> Void
    let onTapImportFromFiles: () -> Void
    
    @Environment(\.dismiss) var dissmiss
    
    var body: some View {
        VStack(spacing: 0) {
            grabberView
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            containerView
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
    
    private var grabberView: some View {
        Rectangle()
            .frame(width: 36, height: 5)
            .foregroundStyle(Color(hex: "#CCCCCC") ?? .gray)
    }
    
    private var containerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            containerItemView(type: .scan)
                .onTapGesture {
                    dissmiss()
                    onTapScan()
                }
            
            divider
            
            containerItemView(type: .importFromPhotos)
                .onTapGesture {
                    dissmiss()
                    onTapImportFromPhotos()
                }
            
            divider
            
            containerItemView(type: .importFromFiles)
                .onTapGesture {
                    dissmiss()
                    onTapImportFromFiles()
                }
        }
        .background(
            Color.bg(.surface)
                .cornerRadius(16, corners: .allCorners)
        )
    }
    
    private func containerItemView(type: ContainerType) -> some View {
        HStack(spacing: 12) {
            contentIcon(type: type)
                .padding(7)
                .background(
                    Circle()
                        .foregroundStyle(Color(hex: "#ECF1FF") ?? .blue)
                )
            
            Text(contentTitle(type: type))
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.accent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
    
    private func contentIcon(type: ContainerType) -> some View {
        var icon: AppIcon
        switch type {
        case .scan:
            icon = .scanner
        case .importFromPhotos:
            icon = .picture
        case .importFromFiles:
            icon = .folder2
        }
        
        return Image(appIcon: icon)
            .renderingMode(.template)
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundStyle(.elements(.accent))
    }
    
    private func contentTitle(type: ContainerType) -> String {
        switch type {
        case .scan:
            return "Scan document"
        case .importFromPhotos:
            return "Import from photos"
        case .importFromFiles:
            return "Import from files"
        }
    }
    
    private var divider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(.divider(.default))
            .padding(.horizontal, 16)
    }
}
