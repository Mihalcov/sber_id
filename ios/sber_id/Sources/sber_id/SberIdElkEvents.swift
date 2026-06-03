import Flutter

final class SberIdElkStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = SberIdElkStreamHandler()
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func notify(viewId: Int64, type: String, extra: [String: Any] = [:]) {
        var payload: [String: Any] = ["viewId": viewId, "type": type]
        extra.forEach { payload[$0.key] = $0.value }
        eventSink?(payload)
    }
}
