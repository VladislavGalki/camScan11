import Foundation

@MainActor
protocol ErasePageDelegate: AnyObject {
    func didChangePage(index: Int)
    func didStartScroll()
    func didCommitStroke(_ stroke: Stroke, onPage pageIndex: Int)
}
