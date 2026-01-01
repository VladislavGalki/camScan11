import SwiftUI

struct IdCameraView: View {
    @ObservedObject var ui: ScanUIStateStore

    var body: some View {
        if ui.isIdIntroVisible {
            intro
        } else {
            frameOverlay
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Spacer()

            Rectangle()
                .fill(Color.white)
                .overlay {
                    Text(ui.selectedIdType.title)
                        .foregroundStyle(.black)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(width: 220, height: 140)
                .padding(.bottom, 64)

            Spacer()
            
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(IdDocumentTypeEnum.allCases) { type in
                        Text(type.title)
                            .foregroundStyle(ui.selectedIdType == type ? Color.black : Color.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                Rectangle()
                                    .fill(ui.selectedIdType == type ? Color.white : Color.gray.opacity(0.65))
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture { ui.selectedIdType = type }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)
            .padding(.bottom, 16)

            Button {
                ui.isIdIntroVisible = false
            } label: {
                Text("Создать сейчас")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 22)
            }
        }
        .padding(.vertical, 16)
    }

    private var frameOverlay: some View {
        IdFrameOverlayRepresentable(
            layout: layoutForSelectedType(),
            cornerRadius: 18,
            title: ui.selectedIdType.title
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
    }

    private func layoutForSelectedType() -> IdFrameOverlayView.Layout {
        switch ui.selectedIdType {
        case .general:
            // "Общий"
            return .padded(horizontalPadding: 16, verticalPadding: 90, height: 220)

        case .identification:
            return .padded(horizontalPadding: 16, verticalPadding: 90, height: 240)

        case .driverLicense:
            return .padded(horizontalPadding: 16, verticalPadding: 110, height: 200)

        case .passport:
            // паспорт — выше/вертикальнее
            return .padded(horizontalPadding: 16, verticalPadding: 32, height: 440)

        case .bankCard:
            // карта — ниже по высоте
            return .padded(horizontalPadding: 16, verticalPadding: 130, height: 180)
        }
    }
}
