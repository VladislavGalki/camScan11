import SwiftUI

private enum SignatureContainerType {
    case createSignature
    case scanSignature
    case importFromPhotos
}

struct SignatureBottomSheetView: View {
    let onTapCreateSignature: () -> Void
    let onTapScanSignature: () -> Void
    let onTapImportFromPhotos: () -> Void

    @Environment(\.dismiss) private var dismiss

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
            containerItemView(type: .createSignature)
                .onTapGesture {
                    dismiss()
                    onTapCreateSignature()
                }

            divider

            containerItemView(type: .scanSignature)
                .onTapGesture {
                    dismiss()
                    onTapScanSignature()
                }

            divider

            containerItemView(type: .importFromPhotos)
                .onTapGesture {
                    dismiss()
                    onTapImportFromPhotos()
                }
        }
        .background(
            Color.bg(.surface)
                .cornerRadius(16, corners: .allCorners)
        )
    }

    private func containerItemView(type: SignatureContainerType) -> some View {
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

    private func contentIcon(type: SignatureContainerType) -> some View {
        let icon: AppIcon

        switch type {
        case .createSignature:
            icon = .signature
        case .scanSignature:
            icon = .scanner
        case .importFromPhotos:
            icon = .picture
        }

        return Image(appIcon: icon)
            .renderingMode(.template)
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundStyle(.elements(.accent))
    }

    private func contentTitle(type: SignatureContainerType) -> String {
        switch type {
        case .createSignature:
            return "Create a signature"
        case .scanSignature:
            return "Scan a signature"
        case .importFromPhotos:
            return "Import from photos"
        }
    }

    private var divider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(.divider(.default))
            .padding(.horizontal, 16)
    }
}
