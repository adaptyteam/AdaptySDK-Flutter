//
//  SwiftAdaptyNativeView.swift
//  Pods
//
//  Created by Alexey Goncharov on 8/5/25.
//

import Adapty
import AdaptyPlugin
import AdaptyUI
import Flutter
import UIKit

class AdaptyPaywallNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let eventHandler: EventHandler

    init(
        messenger: FlutterBinaryMessenger,
        eventHandler: EventHandler
    ) {
        self.messenger = messenger
        self.eventHandler = eventHandler

        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return AdaptyPaywallNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            eventHandler: eventHandler
        )
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class AdaptyPaywallNativeView: NSObject, FlutterPlatformView {
    private var _view: FlowPlatformRootView

    private let viewId: Int64
    private let paywallJsonString: String?
    private let eventHandler: EventHandler

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        eventHandler: EventHandler
    ) {
        _view = FlowPlatformRootView()
        self.viewId = viewId
        self.eventHandler = eventHandler

        paywallJsonString = args as? String

        super.init()

        if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
            createNativeView(view: _view)
        } else {
            // Flows render on iOS 16 and later; below that the platform view stays empty
            // and reports the failure as a flow view error, like AdaptyUI.createFlowView does.
            Log.wrapper.error("Adapty flows require iOS 16.0 or newer")
            reportPlatformNotSupported()
        }
    }

    private func reportPlatformNotSupported() {
        let view = FlowViewIdentity(
            viewId: "flutter_native_\(viewId)",
            creationParams: paywallJsonString
        )
        // Sent once the platform view creation returns. The event may still reach Dart before
        // the widget listens for this view; the Dart side keeps it until the widget does.
        Task { @MainActor [eventHandler] in
            eventHandler.handle(event: FlowViewErrorEvent(view: view, error: .ui(.platformNotSupported)))
        }
    }

    func view() -> UIView {
        return _view
    }

    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    private func createNativeView(view _view: FlowPlatformRootView) {
        Task { @MainActor in
            do {
                guard let paywallJsonString else {
                    throw AdaptyPluginError.platformViewError("Paywall Configuration Data Not Found")
                }

                let configuration = try await AdaptyPlugin.getFlowViewConfiguration(
                    withJson: paywallJsonString
                )

                // The flow joins the view controller that shows this view. While the view is not in
                // a window yet, that is the Flutter view controller in the key window of the active
                // scene; without one, the flow is added once there is one.
                _view.whenHosted { [viewId, eventHandler] view, parentVC in
                    let uiView = AdaptyFlowPlatformViewWrapper(
                        viewId: "flutter_native_\(viewId)",
                        eventHandler: eventHandler,
                        configuration: configuration,
                        parentVC: parentVC
                    )

                    view.addSubview(uiView)

                    uiView.translatesAutoresizingMaskIntoConstraints = false
                    view.addConstraints([
                        uiView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        uiView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        uiView.topAnchor.constraint(equalTo: view.topAnchor),
                        uiView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    ])
                }
            } catch {
                // The view stays empty. Report the failure as a flow view error with the code and
                // message of the error AdaptyUI.createFlowView fails with the same way, or as the
                // plugin's platform view error when createFlowView has no such failure.
                Log.wrapper.error(error.localizedDescription)
                eventHandler.handle(event: FlowViewErrorEvent(
                    view: FlowViewIdentity(
                        viewId: "flutter_native_\(viewId)",
                        creationParams: paywallJsonString
                    ),
                    error: FlowViewError(error)
                ))
            }
        }
    }
}

/// The `flow_view_did_receive_error` event of an embedded flow view that never showed its flow:
/// below iOS 16, or when the flow fails to load.
private struct FlowViewErrorEvent: AdaptyPluginEvent {
    let id = "flow_view_did_receive_error"
    let view: FlowViewIdentity
    let error: FlowViewError

    enum CodingKeys: String, CodingKey {
        case id
        case view
        case error
    }
}

/// The error of an embedded flow view, with the code and message of the error that
/// AdaptyUI.createFlowView fails with in the same case, if it has one. An AdaptyError or
/// AdaptyUIError is encoded as in the bridge's own events, so its detail is the error's
/// description, while a failed createFlowView call carries the error as JSON in its detail.
private enum FlowViewError: Encodable, Sendable {
    case adapty(AdaptyError)
    case ui(AdaptyUIError)
    case plugin(AdaptyPluginError)
    case other(code: Int, message: String, detail: String)

    init(_ error: Error) {
        switch error {
        case let error as AdaptyError:
            self = .adapty(error)
        case let error as AdaptyUIError:
            self = .ui(error)
        case let error as AdaptyPluginError:
            self = .plugin(error)
        case let error as DecodingError:
            // As the bridge fails a create flow view request whose params it can't decode.
            let message = "Request params of method:adapty_ui_create_flow_view is invalid"
            self = .other(
                code: AdaptyError.ErrorCode.decodingFailed.rawValue,
                message: "\(message): \(error.localizedDescription)",
                detail: "AdaptyPluginError.decodingFailed: \(message) \(String(describing: error))"
            )
        default:
            // As the bridge fails a request with an error it doesn't know.
            self = .other(
                code: AdaptyError.ErrorCode.unknown.rawValue,
                message: "Unknown: \(error.localizedDescription)",
                detail: "AdaptyPluginError.unknown: \(String(describing: error))"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case code = "adapty_code"
        case message
        case detail
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .adapty(error):
            try error.encode(to: encoder)
        case let .ui(error):
            try error.encode(to: encoder)
        case let .plugin(error):
            try error.encode(to: encoder)
        case let .other(code, message, detail):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(code, forKey: .code)
            try container.encode(message, forKey: .message)
            try container.encode(detail, forKey: .detail)
        }
    }
}

/// The `AdaptyUI.FlowView` of an embedded flow view that was never built: its id and the
/// placement and variation of the flow from the creation params.
private struct FlowViewIdentity: Encodable, Sendable {
    let id: String
    let placementId: String
    let variationId: String

    enum CodingKeys: String, CodingKey {
        case id
        case placementId = "placement_id"
        case variationId = "variation_id"
    }

    init(viewId: String, creationParams: String?) {
        let params = creationParams
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let flow = params?["flow"] as? [String: Any]
        let placement = flow?["placement"] as? [String: Any]

        id = viewId
        placementId = placement?["developer_id"] as? String ?? ""
        variationId = flow?["variation_id"] as? String ?? ""
    }
}

/// The view of an embedded flow view. Finds the view controller that shows it, which the flow is
/// added to, and waits for one while there is none.
private final class FlowPlatformRootView: UIView {
    private static let hostChangeNotifications: [Notification.Name] = [
        UIScene.didActivateNotification,
        UIApplication.didBecomeActiveNotification,
        UIWindow.didBecomeKeyNotification,
    ]

    private var pendingWork: ((FlowPlatformRootView, UIViewController) -> Void)?

    /// Runs `work` with the view controller to add the flow to: right away when there is one, or
    /// else once this view moves to a window, a scene or the app becomes active or a window
    /// becomes key.
    func whenHosted(_ work: @escaping (FlowPlatformRootView, UIViewController) -> Void) {
        if let parentVC = hostViewController {
            work(self, parentVC)
            return
        }
        pendingWork = work
        for name in Self.hostChangeNotifications {
            NotificationCenter.default.addObserver(self, selector: #selector(runPendingWork), name: name, object: nil)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            runPendingWork()
        }
    }

    @objc private func runPendingWork() {
        guard let work = pendingWork, let parentVC = hostViewController else { return }
        pendingWork = nil
        for name in Self.hostChangeNotifications {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        work(self, parentVC)
    }

    /// In a window, the view controller whose view contains this view, found up the responder
    /// chain, so any scene state, window and container works. Before that, the Flutter view
    /// controller in the key window of the active scene, as before.
    private var hostViewController: UIViewController? {
        if window != nil {
            var responder = next
            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }
                responder = current.next
            }
        }
        return UIApplication.shared.flutterCanvasViewController()
    }
}

extension UIApplication {
    @MainActor
    func flutterCanvasViewController() -> FlutterViewController? {
        // Resolve via UIScene (UIApplication.shared.windows is deprecated and
        // returns differently under iOS 26 SDK linkage) and walk the VC tree
        // so add-to-app hosts (Flutter inside a UIKit/SwiftUI container) work.
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return Self.findFlutterViewController(in: root)
    }

    @MainActor
    private static func findFlutterViewController(in vc: UIViewController) -> FlutterViewController? {
        if let flutter = vc as? FlutterViewController { return flutter }
        // Check presented before children: a Flutter VC presented modally over
        // a UIKit host should win over a stale embedded one deeper in the tree.
        if let presented = vc.presentedViewController,
           let found = findFlutterViewController(in: presented) {
            return found
        }
        for child in vc.children {
            if let found = findFlutterViewController(in: child) { return found }
        }
        return nil
    }
}
