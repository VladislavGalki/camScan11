//
//  IdCardDriverLicenseView.swift
//  CamScanner
//
//  Created by Владислав Галкин on 29.01.2026.
//

import SwiftUI

struct IdCardDriverLicenseView: View {
    @ObservedObject var ui: ScanUIStateStore
    
    var body: some View {
        IdCardDriverLicenseFrameOverlayRepresentable(
            layout: .aspectFit(
                horizontalPadding: 44,
                verticalPadding: 90,
                aspect: 314.0 / 202.0
            ),
            title: titleText,
            guideImage: nil
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
    }
    
    private var titleText: String {
        ui.idCaptureSide == .front ? "Front side" : "Back side"
    }
}
