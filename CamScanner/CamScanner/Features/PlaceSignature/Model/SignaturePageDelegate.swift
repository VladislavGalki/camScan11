import Foundation
import CoreGraphics

@MainActor
protocol SignaturePageDelegate: AnyObject {
    func didTapPage(index: Int)
    func didTapSignature(id: UUID)
    func didMoveSignature(id: UUID, to center: CGPoint)
    func didResizeRotateSignature(id: UUID, width: CGFloat, height: CGFloat, rotation: CGFloat)
    func didEndResizeRotate(id: UUID)
    func didChangePageSize(_ size: CGSize)
    func didStartScroll()
    func didChangeSelectedSignatureFrame(id: UUID, rect: CGRect?)
    func didChangePage(index: Int)
}
