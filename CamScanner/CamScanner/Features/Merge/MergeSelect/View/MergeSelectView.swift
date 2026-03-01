import SwiftUI
import Combine
import UIKit

struct MergeSelectView: View {
    @StateObject private var vm = MergeSelectViewModel()
    @EnvironmentObject private var router: Router

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if vm.items.isEmpty {
                    Text("Пока нет документов")
                        .foregroundStyle(.gray)
                        .padding(.top, 60)
                } else {
                    ForEach(vm.items) { item in
                        Button {
                            vm.toggle(item.id)
                        } label: {
                            MergeSelectRow(
                                item: item,
                                thumbnail: vm.thumbnails[item.id],
                                isSelected: vm.selected.contains(item.id)
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Объединить")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                router.push(
                    MergeRoute.arrangeDocuments(ids: vm.selectedInOrder)
                )            } label: {
                Text("Объединить (\(vm.selected.count))")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.selected.count < 2 ? Color.gray.opacity(0.3) : Color.green)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .disabled(vm.selected.count < 2)
            .background(Color.white.ignoresSafeArea())
        }
    }
}

private struct MergeSelectRow: View {
    let item: DocumentListItem
    let thumbnail: UIImage?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2))
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.black.opacity(0.7))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSelected ? Color.green : Color.gray.opacity(0.5))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private var title: String {
        return ""
//        let kind = item.kind.lowercased()
//        if kind == "id" { return "\(item.idType ?? "ID") • \(item.pageCount) стр." }
//        return "Скан • \(item.pageCount) стр."
    }

    private var subtitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: item.createdAt)
    }
}
