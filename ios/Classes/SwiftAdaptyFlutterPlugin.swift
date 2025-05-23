import Adapty
import AdaptyPlugin
import AdaptyUI
import Flutter
import Foundation

enum Log {
    typealias Category = AdaptyPlugin.LogCategory

    static let wrapper = Category(subsystem: "io.adapty.flutter", name: "wrapper")
}

public final class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter.adapty.com/adapty"
    fileprivate static var channel: FlutterMethodChannel?
    private static let pluginInstance = SwiftAdaptyFlutterPlugin()

    private static let eventHandler = SwiftAdaptyFlutterPluginEventHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        guard SwiftAdaptyFlutterPlugin.channel == nil else {
            Log.wrapper.warn("Attempt to register the plugin twice! Skipping.")
            return
        }

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(Self.pluginInstance, channel: channel)
        registrar.addApplicationDelegate(Self.pluginInstance)

        let factory = AdaptyNativeViewFactory(messenger: registrar.messenger())
        registrar.register(
            factory,
            withId: "adaptyui_onboarding_platform_view"
        )

        Self.channel = channel

        Task { @MainActor in
            AdaptyPlugin.register(setFallbackRequests: { @MainActor assetId in
                let key = FlutterDartProject.lookupKey(forAsset: assetId)
                return Bundle.main.url(forResource: key, withExtension: nil)
            })

            AdaptyPlugin.register(eventHandler: eventHandler)
        }
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Task {
            let response = await AdaptyPlugin.execute(
                method: call.method,
                withJson: call.arguments as? String ?? ""
            )
            result(response.asAdaptyJsonString)
        }
    }
}

final class SwiftAdaptyFlutterPluginEventHandler: EventHandler {
    public func handle(event: AdaptyPluginEvent) {
        do {
            try SwiftAdaptyFlutterPlugin.channel?.invokeMethod(
                event.id,
                arguments: event.asAdaptyJsonData.asAdaptyJsonString
            )
        } catch {
            Log.wrapper.error("Plugin encoding error: \(error.localizedDescription)")
        }
    }
}

import Flutter
import UIKit

class AdaptyNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return AdaptyOnboardingNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class AdaptyOnboardingNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView

    private let viewId: String
    private let onboardingId: String
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView()
        self.viewId = "\(viewId)"
        self.onboardingId = (args as? [String: Any?])?["placement_id"] as? String ?? "test"
        
        super.init()

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
            createNativeView(view: _view)
        }
    }

    func view() -> UIView {
        return _view
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    private func createNativeView(view _view: UIView) {
        Task { @MainActor in
            let onboarding = try await Adapty.getOnboarding(placementId: onboardingId)

            let (uiView, uid) = try AdaptyUI.createOnboardingUIView(
                onboarding: onboarding
            )

            AdaptyPlugin.addOnboardingViewAssociation(
                crossplatformViewId: viewId,
                nativeViewId: uid
            )

            _view.addSubview(uiView)
            
            uiView.translatesAutoresizingMaskIntoConstraints = false
            _view.addConstraints([
                uiView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                uiView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                uiView.topAnchor.constraint(equalTo: _view.topAnchor),
                uiView.bottomAnchor.constraint(equalTo: _view.bottomAnchor),
            ])
        }
    }
}
