import SIDSDK

final class SberIdWebViewDelegate: NSObject, SIDWebViewDelegateProtocol {
    private let onReject: () -> Void

    init(onReject: @escaping () -> Void) {
        self.onReject = onReject
    }

    func webViewReject() {
        onReject()
    }
}
