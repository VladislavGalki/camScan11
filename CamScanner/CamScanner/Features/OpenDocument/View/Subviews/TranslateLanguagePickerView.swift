import SwiftUI

struct TranslateLanguagePickerView: View {
    private enum Layout {
        static let topOverlayHeight: CGFloat = 128
    }

    let initialSelection: TranslateLanguage?
    let onConfirm: (TranslateLanguage) -> Void

    @State private var selectedLanguage: TranslateLanguage?
    @State private var pendingConfirmationLanguage: TranslateLanguage?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredLanguages: [TranslateLanguage] {
        if searchText.isEmpty {
            return TranslateLanguage.allCases
        }
        return TranslateLanguage.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: Layout.topOverlayHeight)

                        if filteredLanguages.isEmpty {
                            emptyState
                                .padding(.horizontal, 16)
                        } else {
                            languageList
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 52)
                        }
                    }
                }
                .onAppear {
                    selectedLanguage = initialSelection

                    if let initialSelection {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(initialSelection.id, anchor: .center)
                            }
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                navigationView

                searchBar
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
            .background(
                ProgressiveBlurView()
                    .blur(radius: 20)
                    .background {
                        LinearGradient(
                            colors: [
                                Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                                Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.5),
                                Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.bg(.main)
        )
        .onDisappear {
            guard let pendingConfirmationLanguage else { return }
            onConfirm(pendingConfirmationLanguage)
            self.pendingConfirmationLanguage = nil
        }
    }

    // MARK: - Navigation Bar
    
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    dismiss()
                }
            )

            Spacer(minLength: 0)
        }
        .overlay {
            Text("Translate to")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(appIcon: .search)
                .renderingMode(.template)
                .foregroundStyle(.elements(.tertiary))

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search language")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.tertiary))
                }

                TextField("", text: $searchText)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.primary))
                    .tint(.bg(.accent))
            }

            if !searchText.isEmpty {
                Image(appIcon: .closeFill)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tertiary))
                    .onTapGesture {
                        searchText = ""
                    }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(
            Color.bg(.controlOnMain)
                .cornerRadius(100)
        )
    }

    // MARK: - Language List

    private var languageList: some View {
        VStack(spacing: 0) {
            ForEach(filteredLanguages) { language in
                languageRow(language)
                    .id(language.id)

                if language != filteredLanguages.last {
                    Divider()
                        .foregroundStyle(.divider(.default))
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(
            Color.bg(.surface)
                .cornerRadius(16)
                .appBorderModifier(.border(.primary), radius: 16)
        )
    }

    private func languageRow(_ language: TranslateLanguage) -> some View {
        HStack(spacing: 12) {
            Image(appIcon: language.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(Circle())

            Text(language.displayName)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))

            Spacer()

            if selectedLanguage == language {
                Image(appIcon: .check)
                    .renderingMode(.template)
                    .foregroundStyle(.bg(.accent))
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedLanguage = language
            pendingConfirmationLanguage = language
            dismiss()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(appIcon: .emptyLanguage)

            Text("No language found")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
        }
        .padding(.top, 100)
    }
}
