import SwiftUI

struct ExploreToolsView: View {
    let model: [ExploreToolModel]
    let onAllToolTapped: () -> Void
    let onToolTapped: (ExploreToolModel.ToolType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model) { item in
                    toolItemView(item)
                        .onTapGesture {
                            onToolTapped(item.type)
                        }
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Explore Tools")
                .appTextStyle(.sectionTitle)
                .foregroundStyle(.text(.primary))
            
            Spacer(minLength: 0)
            
            Button {
                onAllToolTapped ()
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
    
    private func toolItemView(_ item: ExploreToolModel) -> some View {
        HStack(spacing: 16) {
            Image(appIcon: item.icon)
            
            Text(item.title)
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Color.bg(.surface)
                .cornerRadius(16, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 16, corners: .allCorners)
        )
    }
}
