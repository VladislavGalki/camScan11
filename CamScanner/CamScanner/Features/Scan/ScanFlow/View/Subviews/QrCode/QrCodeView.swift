import SwiftUI

struct QrCodeView: View {
    @ObservedObject var ui: ScanUIStateStore
    
    let qrCodeResult: String?
    
    var onCloseQrCodePreview: (() -> Void)?
    
    var body: some View {
        IdCardDriverLicenseFrameOverlayRepresentable(
            layout: .square(size: 250),
            title: "",
            guideImage: nil
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
        .overlay(alignment: .bottom) {
            qrCodeResultView
                .padding([.horizontal, .bottom], 16)
        }
    }
    
    @ViewBuilder
    private var qrCodeResultView: some View {
        if let qrCodeResult {
            HStack(spacing: 12) {
                Image(appIcon: .link)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.onAccent))
                
                Text(qrCodeResult)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.onAccent))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 0)
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Open link"),
                        variant: .secondary,
                        size: .s
                    ),
                    action: {
                        openQRCode(qrCodeResult)
                        onCloseQrCodePreview?()
                    }
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.close),
                        variant: .secondary,
                        size: .s
                    ),
                    action: {
                        onCloseQrCodePreview?()
                    }
                )
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                Color.bg(.accent)
                    .cornerRadius(12, corners: .allCorners)
            )
        }
    }
    
    private func openQRCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil {
            UIApplication.shared.open(url)
            return
        }

        if let url = URL(string: "https://" + trimmed) {
            UIApplication.shared.open(url)
        }
    }
}
