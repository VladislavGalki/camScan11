import SwiftUI
import UIKit

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct OCREditorView: View {

    let title: String
    @Binding var text: String
    let onClose: () -> Void
    
    @State private var sharePayload: SharePayload? = nil

    @Environment(\.dependencies) private var dependencies

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(12)
                    .padding(16)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportTXT()
                    } label: {
                        Image(systemName: "doc.plaintext")
                    }
                }
            }
            .sheet(item: $sharePayload) { payload in
                DocumentExporterSheet(items: payload.items) {
                    sharePayload = nil
                }
            }
        }
    }
    
    private func exportTXT() {
        do {
            let url = try dependencies.textExporter.exportTXT(
                text: text,
                fileName: "OCR_Text"
            )
            DispatchQueue.main.async {
                self.sharePayload = SharePayload(items: [url])
            }
        } catch {
        }
    }
}
