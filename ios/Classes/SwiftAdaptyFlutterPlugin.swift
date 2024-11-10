//import Adapty
import AdaptyCrossPlatformCommon
//import AdaptyUI
import Flutter

public final class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    private static var channel: FlutterMethodChannel?
    private static let pluginInstance = SwiftAdaptyFlutterPlugin()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: SwiftAdaptyFlutterConstants.channelName,
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(Self.pluginInstance, channel: channel)
        registrar.addApplicationDelegate(Self.pluginInstance)

        Self.channel = channel

//        Adapty.delegate = Self.pluginInstance
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Task {
            let arguments = call.arguments as? [String: Any] ?? [:]
            let callResult = await AdaptyPlugin.request(
                method: call.method,
                json: arguments
            )
            let callResultJson = callResult.asAdaptyJsonString
            result(callResultJson)
        }
    }
}

//extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
//    static var dateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.calendar = Calendar(identifier: .iso8601)
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
//        return formatter
//    }()
//
//    static var jsonEncoder: JSONEncoder = {
//        let encoder = JSONEncoder()
//        encoder.dateEncodingStrategy = .formatted(dateFormatter)
//        encoder.dataEncodingStrategy = .base64
//        return encoder
//    }()
//
//    public func didLoadLatestProfile(_ profile: AdaptyProfile) {
//        guard let data = try? SwiftAdaptyFlutterPlugin.jsonEncoder.encode(profile) else { return }
//        Self.channel?.invokeMethod(MethodName.didUpdateProfile.rawValue, arguments: String(data: data, encoding: .utf8))
//    }
//}
