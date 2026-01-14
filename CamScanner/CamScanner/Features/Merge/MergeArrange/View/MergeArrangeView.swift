import SwiftUI
import UIKit

struct MergeArrangeView: View {
    @StateObject private var vm: MergeArrangeViewModel
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    init(inputIDs: [UUID]) {
        _vm = StateObject(wrappedValue: MergeArrangeViewModel(docIDs: inputIDs))
    }

    var body: some View {
        List {
            ForEach(vm.items) { item in
                HStack(spacing: 12) {
                    if let thumb = vm.thumbnails[item.id] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 54, height: 54)
                            .overlay { ProgressView() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.title(for: item))
                            .font(.system(size: 15, weight: .semibold))
                        Text("Документ")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .onMove(perform: vm.move)
        }
        .listStyle(.plain)
        .navigationTitle("Порядок")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                vm.mergeAndSave { _ in
                    // после сохранения вернемся назад (или можно popToRoot / открыть новый документ)
                    dismiss()
                }
            } label: {
                Text("Объединить")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}
