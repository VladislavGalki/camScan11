import SwiftUI
import UIKit

struct TranslatorView: View {
    enum Segment: CaseIterable {
        case translated
        case original

        static let allCases: [Segment] = [.translated, .original]
    }

    private enum Layout {
        static let textContainerCornerRadius: CGFloat = 24
    }

    let translatedText: String
    let originalText: String
    let selectedLanguage: TranslateLanguage
    let documentName: String
    let onDismiss: () -> Void
    let onTapLanguage: () -> Void

    @State private var selectedSegment: Segment = .translated
    @State private var sharePayload: TranslatorSharePayload?
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.bottom, 8)

            segmentControl
                .padding(.horizontal, 16)
                .padding(.bottom, 25)

            textView
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            Spacer(minLength: 0)

            bottomBarView
        }
        .background(Color.bg(.main))
        .overlay(alignment: .top) {
            if showCopiedToast {
                NotificationToast(
                    isPresented: $showCopiedToast,
                    title: "Copied"
                )
            }
        }
        .sheet(item: $sharePayload) { payload in
            DocumentExporterSheet(items: payload.items) {
                sharePayload = nil
            }
        }
    }
}

private extension TranslatorView {
    var headerView: some View {
        HStack {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: onDismiss
            )

            Spacer(minLength: 0)
        }
        .overlay {
            Text("Translator")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(Array(Segment.allCases.enumerated()), id: \.element) { index, segment in
                segmentButton(segment, index: index)
            }
        }
        .padding(4)
        .frame(height: 36)
        .background {
            GeometryReader { proxy in
                let count = CGFloat(Segment.allCases.count)
                let segmentWidth = proxy.size.width / max(count, 1)
                let selectedIndex = CGFloat(selectedSegmentIndex)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.bg(.controlOnMain))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.bg(.accent))
                            .frame(width: segmentWidth - 8, height: 28)
                            .offset(x: selectedIndex * segmentWidth + 4)
                            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
                    }
            }
        }
        .clipped()
    }

    func segmentButton(_ segment: Segment, index: Int) -> some View {
        let isSelected = selectedSegment == segment

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedSegment = segment
            }
        } label: {
            Text(title(for: segment))
                .appTextStyle(.bodySecondary)
                .foregroundStyle(
                    isSelected
                    ? Color.text(.onAccent)
                    : Color.text(.secondary)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var textView: some View {
        ScrollView {
            Text(displayedText)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: Layout.textContainerCornerRadius)
        )
        .cornerRadius(Layout.textContainerCornerRadius)
    }

    var bottomBarView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(appIcon: selectedLanguage.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                Text("Language")
                    .appTextStyle(.tabBar)
                    .foregroundStyle(.text(.secondary))
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                onTapLanguage()
            }

            VStack(spacing: 4) {
                Image(appIcon: .copy)

                Text("Copy text")
                    .appTextStyle(.tabBar)
                    .foregroundStyle(.text(.secondary))
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                UIPasteboard.general.string = displayedText
                showCopiedToast = true
            }

            VStack(spacing: 4) {
                Image(appIcon: .share)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.primary))

                Text("Share")
                    .appTextStyle(.tabBar)
                    .foregroundStyle(.text(.secondary))
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                shareAsTXT()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 19)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    var displayedText: String {
        switch selectedSegment {
        case .translated:
            translatedText
        case .original:
            originalText
        }
    }

    var selectedSegmentIndex: Int {
        Segment.allCases.firstIndex(of: selectedSegment) ?? 0
    }

    func title(for segment: Segment) -> String {
        switch segment {
        case .translated:
            selectedLanguage.displayName
        case .original:
            "Original"
        }
    }

    func shareAsTXT() {
        do {
            let fileNameBase = documentName.isEmpty ? "Translated_Text" : documentName + "_Translated"
            let url = try TextExporter.shared.exportTXT(
                text: displayedText,
                fileName: fileNameBase
            )
            sharePayload = TranslatorSharePayload(items: [url])
        } catch {}
    }
}

private struct TranslatorSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
