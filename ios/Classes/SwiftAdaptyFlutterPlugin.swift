import Adapty
import AdaptyPlugin
import AdaptyUI
import Flutter
import Foundation

private let log = Log.wrapper

public final class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter.adapty.com/adapty"
    private static var channel: FlutterMethodChannel?
    private static let pluginInstance = SwiftAdaptyFlutterPlugin()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(Self.pluginInstance, channel: channel)
        registrar.addApplicationDelegate(Self.pluginInstance)

        Self.channel = channel

        Adapty.delegate = Self.pluginInstance
        
        Task { @MainActor in
            AdaptyPlugin.reqister(requests: [Request.SetFallbackPaywalls.self])
            
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
                AdaptyUI.universalDelagate = SwiftAdaptyFlutterPluginDelegate(channel: channel)
            }
        }
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Task {
            let response = await AdaptyPlugin.execute(
                method: call.method,
                withJson: call.arguments as? [String: Any] ?? [:]
            )
            result(response.asAdaptyJsonString)
        }
    }
}



extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
    public nonisolated func didLoadLatestProfile(_ profile: AdaptyProfile) {
        do {
            try Self.channel?.invokeMethod(
                Method.didLoadLatestProfile.rawValue,
                arguments: [Argument.profile.rawValue: profile.asAdaptyJsonData.asAdaptyJsonString]
            )
        } catch {
            log.error("Plugin encoding error: \(error.localizedDescription)")
        }
    }
}
