import SwiftUI

struct ScanSettingsOverlayCard: View {

    @Binding var isPresented: Bool

    @AppStorage(ScanSettingsKeys.autoShoot) private var autoShoot: Bool = false
    @AppStorage(ScanSettingsKeys.grid) private var grid: Bool = false
    @AppStorage(ScanSettingsKeys.textOrientationRotate) private var textRotate: Bool = true
    @AppStorage(ScanSettingsKeys.volumeShutter) private var volumeShutter: Bool = true
    @AppStorage(ScanSettingsKeys.autoCrop) private var autoCrop: Bool = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Настройки")
                        .font(.title3).bold()
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }

                ToggleRow(title: "Автосъёмка", isOn: $autoShoot)
                ToggleRow(title: "Сетка", isOn: $grid)
                ToggleRow(title: "Поворот по ориентации текста", isOn: $textRotate, tint: .green)
                ToggleRow(title: "Снять клавишей Громкости", isOn: $volumeShutter, tint: .green)
                ToggleRow(title: "Автообрезка", isOn: $autoCrop, tint: .green)

                Divider().background(Color.white.opacity(0.2))

                Button { } label: {
                    Text("Больше настроек")
                        .foregroundStyle(.cyan)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var tint: Color = .white

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
        }
    }
}
