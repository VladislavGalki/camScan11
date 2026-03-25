import Foundation
import CoreGraphics

@MainActor
protocol AddTextPageDelegate: AnyObject {
    func didTapPage(index: Int, location: CGPoint, initialSize: CGSize)
    func didTapText(id: UUID)
    func didMoveText(id: UUID, to center: CGPoint)
    func didResizeText(id: UUID, width: CGFloat, centerX: CGFloat?, pageSize: CGSize)
    func didChangePageSize(_ size: CGSize)
    func didChangeResizeState(isResizing: Bool)
    func didChangeEditingText(_ text: String, pageSize: CGSize)
    func didSubmitEditing()
    func didStartScroll()
    func didChangeSelectedTextFrame(id: UUID, rect: CGRect?)
    func didChangePage(index: Int)
}
