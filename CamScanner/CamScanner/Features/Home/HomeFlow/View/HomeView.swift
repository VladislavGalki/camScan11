import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    
    @EnvironmentObject private var router: Router
    
    // ✅ для подтверждения удаления
    @State private var deleteCandidate: DocumentListItem? = nil
    @State private var showDeleteAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBarView
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RecentView(model: vm.recentModel) {
                        // click plus button
                    } onDocumentTapped: { item in
                        if !item.isLocked {
                            router.push(HomeRoute.openDocument(id: item.id))
                        }
                    }
                    .padding(.bottom, 26)
                    
                    ExploreToolsView(model: vm.exploreToolModel) {
                        // all click
                    } onToolTapped: { toolType in
                        // click on type
                    }
                    .padding(.horizontal, 16)
                }
            }
            .scrollIndicators(.never)
            .contentMargins(.top, 26, for: .scrollContent)
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)

//        ScrollView {
//            LazyVStack(spacing: 12) {
//                if vm.items.isEmpty {
//                    emptyState
//                } else {
//                    ForEach(vm.items) { item in
//                        DocumentCard(
//                            item: item,
//                            thumbnail: vm.thumbnails[item.id]
//                        )
//                        .padding(.horizontal, 16)
//                        .onTapGesture {
//                            if !item.isLocked {
//                                router.push(HomeRoute.openDocument(id: item.id))
//                                return
//                            }
//                            
//                            PasswordPromptView.shared.present(
//                                title: "Введите пароль",
//                                message: nil
//                            ) { password in
//                                let ok = (try? DocumentRepository.shared.verifyPassword(
//                                    docID: item.id,
//                                    password: password
//                                )) ?? false
//
//                                if ok {
//                                    router.push(HomeRoute.openDocument(id: item.id))
//                                }
//                            } onRemove: { password in
//                                try? DocumentRepository.shared.removePassword(
//                                    docID: item.id,
//                                    password: password
//                                )
//                            }
//                        }
//                        .contextMenu {
//                            Button(role: .destructive) {
//                                deleteCandidate = item
//                                showDeleteAlert = true
//                            } label: {
//                                Label("Удалить", systemImage: "trash")
//                            }
//                            Button("Установить пароль") {
//                                PasswordPromptView.shared.present(
//                                    title: "Установить пароль",
//                                    message: "До 6 символов"
//                                ) { password in
//                                    try? DocumentRepository.shared.setPassword(
//                                        docID: item.id,
//                                        password: password
//                                    )
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            .padding(.top, 12)
//            .padding(.bottom, 24)
//        }
//        .background(Color.white.ignoresSafeArea())
//        .navigationTitle("Главная")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                Button {
//                    router.push(MergeRoute.selectDocuments)
//                } label: {
//                    Image(systemName: "square.stack.3d.up")
//                }
//            }
//        }
//        .alert("Удалить документ?", isPresented: $showDeleteAlert) {
//            Button("Удалить", role: .destructive) {
//                guard let doc = deleteCandidate else { return }
//                vm.delete(docID: doc.id)
//                deleteCandidate = nil
//            }
//            Button("Отмена", role: .cancel) {
//                deleteCandidate = nil
//            }
//        } message: {
//            Text("Документ и все его страницы будут удалены без возможности восстановления.")
//        }
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.surface))
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
            .appBorderModifier(.border(.primary), radius: 32, corners: [.bottomLeft, .bottomRight])
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Home")
                        .appTextStyle(.screenTitle)
                        .foregroundStyle(.text(.primary))
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 8) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.search),
                                variant: .secondary,
                                size: .m
                            ),
                            action: {}
                        )
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .titleWithIcon(
                                    title: "Get PRO",
                                    icon: .starFill
                                ),
                                variant: .primary,
                                size: .m
                            ),
                            action: {}
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }
}

//// MARK: - Card
//
//private struct DocumentCard: View {
//    
//    let item: DocumentListItem
//    let thumbnail: UIImage?
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            ZStack {
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color.white.opacity(0.06))
//                
//                if let thumbnail {
//                    Image(uiImage: thumbnail)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 72, height: 72)
//                        .clipped()
//                        .cornerRadius(12)
//                } else {
//                    ProgressView().tint(.white.opacity(0.7))
//                }
//            }
//            .frame(width: 72, height: 72)
//            .overlay(
//                RoundedRectangle(cornerRadius: 12)
//                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
//            )
//            
//            VStack(alignment: .leading, spacing: 6) {
//                Text(title)
//                    .font(.system(size: 16, weight: .semibold))
//                    .foregroundStyle(.black)
//                
//                Text(subtitle)
//                    .font(.system(size: 13))
//                    .foregroundStyle(.black)
//            }
//            
//            Spacer()
//            
//            Image(systemName: "chevron.right")
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundStyle(.black)
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(Color.gray)
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(Color.white.opacity(0.10), lineWidth: 1)
//        )
//    }
//    
//    private var title: String {
//        let kind = item.kind.lowercased()
//        if kind == "id" {
//            return "\(item.idType ?? "ID") • \(item.pageCount) стр."
//        }
//        return "Скан • \(item.pageCount) стр."
//    }
//    
//    private var subtitle: String {
//        let df = DateFormatter()
//        df.locale = Locale(identifier: "ru_RU")
//        df.dateStyle = .medium
//        df.timeStyle = .short
//        return df.string(from: item.createdAt)
//    }
//}
