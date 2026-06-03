import Flutter
import SIDSDK
import UIKit

private final class SberIdElkHeightDelegate: NSObject, SIDTableViewHeightDelegate {
    func updateHeight() {}
}

private final class SberIdElkEventHandler: NSObject, SIDElkEventHandler {
    private let viewId: Int64

    init(viewId: Int64) {
        self.viewId = viewId
    }

    func handleEvent(elkEvent: SIDElkEvent) {
        let type: String
        var extra: [String: Any] = [:]
        switch elkEvent {
        case .showELK:
            type = "show"
        case .hideELK:
            type = "hide"
        case .errorELK:
            type = "error"
        case .reloadELK:
            type = "reload"
        case .clickELK(let widgetName):
            type = "click"
            extra["widgetName"] = widgetName
        case .widgetErrorELK(let widgetName, let httpStatusCode, let partnerErrorCode):
            type = "widgetError"
            extra["widgetName"] = widgetName
            extra["httpStatusCode"] = httpStatusCode
            if let partnerErrorCode = partnerErrorCode {
                extra["partnerErrorCode"] = partnerErrorCode
            }
        default:
            type = "unknown"
        }
        SberIdElkStreamHandler.shared.notify(viewId: viewId, type: type, extra: extra)
    }

    func openWidgetELK(widgetName: String, clickCallback: String) {
        SberIdElkStreamHandler.shared.notify(
            viewId: viewId,
            type: "openWidget",
            extra: ["widgetName": widgetName, "clickCallback": clickCallback]
        )
    }
}

final class SberIdElkPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView

    init(frame: CGRect, viewId: Int64, args: Any?) {
        let params = args as? [String: Any]
        let additionalPath = params?["containerName"] as? String
        let version = (params?["containerVersion"] as? NSNumber)?.intValue
        let height = (params?["height"] as? NSNumber)?.doubleValue ?? 400

        let factory = SIDPersonalCabinetContainerFactory()
        let manager = factory.createContainer(
            additionalPath: additionalPath,
            version: version,
            heightDelegate: SberIdElkHeightDelegate(),
            elkEventHandler: SberIdElkEventHandler(viewId: viewId)
        )
        let tableView = manager.tableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.frame = CGRect(x: 0, y: 0, width: frame.width, height: height)

        containerView = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: height))
        containerView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        super.init()
    }

    func view() -> UIView {
        containerView
    }
}

final class SberIdElkFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        SberIdElkPlatformView(frame: frame, viewId: viewId, args: args)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
