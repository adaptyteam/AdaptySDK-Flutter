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

        let paywallViewFactory = AdaptyPaywallNativeViewFactory(
            messenger: registrar.messenger(),
            eventHandler: eventHandler
        )
        
        let onboardingViewFactory = AdaptyOnboardingNativeViewFactory(
            messenger: registrar.messenger(),
            eventHandler: eventHandler
        )
        
        registrar.register(
            paywallViewFactory,
            withId: "adaptyui_paywall_platform_view"
        )
        
        registrar.register(
            onboardingViewFactory,
            withId: "adaptyui_onboarding_platform_view"
        )

        registrar.addMethodCallDelegate(Self.pluginInstance, channel: channel)
        registrar.addApplicationDelegate(Self.pluginInstance)

        Self.channel = channel

        Task { @MainActor in
            let flutterAssetResolver: @MainActor @Sendable (String) -> URL? = { assetId in
                let key = FlutterDartProject.lookupKey(forAsset: assetId)
                return Bundle.main.url(forResource: key, withExtension: nil)
            }

            if #available(iOS 15.0, *) {
                AdaptyPlugin.register(createPaywallView: flutterAssetResolver)
            }
            AdaptyPlugin.register(setFallbackRequests: flutterAssetResolver)
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
