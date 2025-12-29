//
//  IdCameraView.swift
//  CamScanner
//
//  Created by Владислав Галкин on 29.12.2025.
//

import SwiftUI

struct IdCameraView: View {
    @StateObject private var viewModel = IdCameraViewModel()
    @State private var shoudShowPreview: Bool = true
    
    var body: some View {
        if shoudShowPreview {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .overlay {
                        Text(viewModel.getSelectedDocumentType()?.title ?? "")
                    }
                    .frame(width: 200)
                    .padding(.bottom, 64)
                
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.documentType) { document in
                            Text(document.title)
                                .foregroundStyle(document.isSelected ? Color.black : Color.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(
                                    Rectangle()
                                        .fill(document.isSelected ? Color.white : Color.gray)
                                )
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture {
                                    viewModel.toggleDocumentType(document)
                                }
                        }
                    }
                }
                .scrollIndicators(.never)
                .padding(.bottom, 16)
                
                Button {
                    shoudShowPreview.toggle()
                } label: {
                    Text("Создать сейчас")
                }
            }
            .padding(.vertical, 16)
        }
    }
}
