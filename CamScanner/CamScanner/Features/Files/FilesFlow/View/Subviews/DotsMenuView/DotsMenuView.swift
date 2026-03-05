import SwiftUI

struct DotsMenuView: View {
    @State private var menuOffset: CGFloat = 0
    
    @Binding var isVisible: Bool

    let dotsFrame: CGRect

    let sortType: FilesSortType
    let viewMode: FilesViewMode

    let onCreateFolder: () -> Void
    let onSelectFiles: () -> Void
    let onSortChange: (FilesSortType) -> Void
    let onViewModeChange: (FilesViewMode) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundView

            if isVisible {
                menuView
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .topTrailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }
    
    var backgroundView: some View {
        Color.black
            .opacity(isVisible ? 0.12 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(isVisible)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isVisible = false
                }
            }
    }
    
    
    var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow("New folder", icon: .folder) {
                close()
                onCreateFolder()
            }

            menuRow("Select files", icon: .check_circle) {
                close()
                onSelectFiles()
            }

            dividerView
                .padding(.vertical, 8)

            sectionTitle("Sort by")

            ForEach(FilesSortType.allCases) { type in
                selectableRow(
                    title: type.title,
                    isSelected: sortType == type
                ) {
                    close()
                    onSortChange(type)
                }
            }

            dividerView
                .padding(.vertical, 8)

            sectionTitle("View by")

            ForEach(FilesViewMode.allCases) { mode in
                selectableRow(
                    title: mode.title,
                    leftIcon: imageByViewMode(mode),
                    isSelected: viewMode == mode
                ) {
                    close()
                    onViewModeChange(mode)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(width: 200)
        .background(Color.bg(.surface))
        .drawingGroup()
        .cornerRadius(24)
        .appBorderModifier(.border(.primary), radius: 24)
        .compositingGroup()
        .shadow(color: .black.opacity(0.05), radius: 10)
        .padding(.trailing, 16)
        .offset(y: dotsFrame.maxY + 64)
        .animation(nil, value: sortType)
        .animation(nil, value: viewMode)
    }
    
    func menuRow(_ title: String, icon: AppIcon, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(appIcon: icon)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.elements(.primary))
                .frame(width: 18, height: 18)

            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))

            Spacer()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }

    func selectableRow(
        title: String,
        leftIcon: Image? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            if let leftIcon {
                leftIcon
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.primary))
                    .frame(width: 18, height: 18)
            }

            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))

            Spacer()

            if isSelected {
                Image(appIcon: .check)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.elements(.accent))
                    .frame(width: 18, height: 18)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
    
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appTextStyle(.meta)
            .foregroundStyle(.text(.secondary))
            .padding(.vertical, 8)
    }

    func imageByViewMode(_ mode: FilesViewMode) -> Image {
        switch mode {
        case .grid:
            return Image(appIcon: .grid2)
        case .list:
            return Image(appIcon: .list)
        }
    }

    var dividerView: some View {
        RoundedRectangle(cornerRadius: 2)
            .foregroundStyle(.divider(.default))
            .frame(height: 1)
    }

    func close() {
        withAnimation(.easeInOut(duration: 0.12)) {
            isVisible = false
        }
    }
}
