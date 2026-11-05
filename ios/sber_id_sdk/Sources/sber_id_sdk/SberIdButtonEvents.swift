import Flutter

final class SberIdButtonStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = SberIdButtonStreamHandler()

    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func notifyPressed(viewId: Int64) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["viewId": viewId])
        }
    }
}
