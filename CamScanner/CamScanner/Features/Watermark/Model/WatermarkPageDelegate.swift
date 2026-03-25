import Foundation
import CoreGraphics

@MainActor
protocol WatermarkPageDelegate: AnyObject {
    func didTapPage(index: Int, location: CGPoint, initialSize: CGSize)
    func didTapWatermark(id: UUID)
    func didMoveWatermark(id: UUID, to center: CGPoint)
    func didChangePageSize(_ size: CGSize)
    func didChangeEditingText(_ text: String, pageSize: CGSize)
    func didSubmitEditing()
    func didStartScroll()
    func didChangeSelectedWatermarkFrame(id: UUID, rect: CGRect?)
    func didChangePage(index: Int)
}
