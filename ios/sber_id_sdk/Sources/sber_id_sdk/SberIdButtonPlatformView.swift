import Flutter
import SIDSDK
import UIKit

final class SberIdButtonObserver: NSObject, SIDLoginButtonObserverProtocol {
    func loginButtonWasHidden() {}
}

final class SberIdButtonPlatformView: NSObject, FlutterPlatformView {
    private let button: SIDLoginButton
    private let viewId: Int64

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.viewId = viewId
        let params = args as? [String: Any]
        let width = (params?["width"] as? NSNumber)?.doubleValue ?? 300
        let height = (params?["height"] as? NSNumber)?.doubleValue ?? 60
        let styleRaw = params?["style"] as? String ?? "green"
        let textTypeRaw = params?["textType"] as? String ?? "general"

        let style: SIDLoginButtonStyle = styleRaw == "white" ? .white : .green
        let textType: SIDLoginButtonTextType
        switch textTypeRaw {
        case "short": textType = .short
        case "filling": textType = .filling
        case "pursue": textType = .pursue
        default: textType = .general
        }

        button = SIDLoginButton(
            type: style,
            textType: textType,
            desiredSize: CGSize(width: width, height: height),
            observer: SberIdButtonObserver()
        )
        super.init()
        button.frame = CGRect(x: 0, y: 0, width: width, height: height)
        button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        SberIdButtonStreamHandler.shared.notifyPressed(viewId: viewId)
    }

    func view() -> UIView {
        return button
    }
}

final class SberIdButtonFactory: NSObject, FlutterPlatformViewFactory {
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
        return SberIdButtonPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
