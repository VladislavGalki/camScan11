import SwiftUI

struct SignaturePickerBottomSheetView: View {
    let onTapAddNew: () -> Void
    let onSelectSignature: (SignatureEntity) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var signatures: [SignatureEntity] = []

    var body: some View {
        VStack(spacing: 0) {
            grabberView
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    addNewCard
                    
                    ForEach(signatures, id: \.id) { signature in
                        signatureCard(signature)
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .padding(.bottom, 8)
        }
        .onAppear {
            loadSignatures()
        }
    }

    // MARK: - Grabber

    private var grabberView: some View {
        Rectangle()
            .frame(width: 36, height: 5)
            .foregroundStyle(Color(hex: "#CCCCCC") ?? .gray)
            .clipShape(Capsule())
    }

    // MARK: - Add New Card

    private var addNewCard: some View {
        VStack(spacing: 8) {
            Image(appIcon: .plus_small)
            
            Text("Add a new")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.accent))
        }
        .frame(width: 150, height: 110)
        .background(
            Color.bg(.surface)
                .cornerRadius(16, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 16)
        )
        .onTapGesture {
            dismiss()
            onTapAddNew()
        }
    }

    // MARK: - Signature Card

    private func signatureCard(_ signature: SignatureEntity) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = loadImage(for: signature) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .frame(width: 150, height: 110)
            } else {
                Color.clear
                    .frame(width: 150, height: 110)
            }

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.trash),
                    style: .secondary,
                    size: .s,
                    extraTitleColor: .elements(.destructive)
                ),
                action: {
                    deleteSignature(signature)
                }
            )
            .padding(8)
        }
        .background(
            Color.bg(.surface)
                .cornerRadius(16, corners: .allCorners)
                .appBorderModifier(.border(.primary), radius: 16)
        )
        .clipShape(Rectangle())
    }

    // MARK: - Data

    private func loadSignatures() {
        signatures = DocumentRepository.shared.fetchSignatures()
    }

    private func loadImage(for signature: SignatureEntity) -> UIImage? {
        let url = FileStore.shared.url(forRelativePath: signature.imagePath)
        return UIImage(contentsOfFile: url.path)
    }

    private func deleteSignature(_ signature: SignatureEntity) {
        try? DocumentRepository.shared.deleteSignature(id: signature.id)
        withAnimation {
            loadSignatures()
        }
        if signatures.isEmpty {
            dismiss()
        }
    }
}
