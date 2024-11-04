import Adapty
import AdaptyCrossPlatformCommon
import AdaptyUI
import Flutter

public final class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        decoder.dataDecodingStrategy = .base64
        return decoder
    }()

    static var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        encoder.dataEncodingStrategy = .base64
        return encoder
    }()

    private static let version = "3.2.0-SNAPSHOT"
    private static var channel: FlutterMethodChannel?
    private static let pluginInstance = SwiftAdaptyFlutterPlugin()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: SwiftAdaptyFlutterConstants.channelName,
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(Self.pluginInstance,
                                        channel: channel)
        registrar.addApplicationDelegate(Self.pluginInstance)

        Self.channel = channel
        
        Adapty.delegate = Self.pluginInstance
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Task {
            let methodName = call.method

            do {
                let resultString = try await AdaptyCrossPlatform.handle(
                    methodName: methodName,
                    arguments: call.arguments as? [String: Any]
                )
                result(resultString)
            } catch {
                if let crossplatformError = error as? AdaptyCrossPlatformError {
                    switch crossplatformError {
                    case .missingParameter(let name):
                        result(
                            FlutterError.missingParameter(
                                name: name,
                                method: methodName,
                                originalError: nil
                            )
                        )
                    case .notImplemented:
                        result(FlutterMethodNotImplemented)
                    }
                } else if let adaptyError = error as? AdaptyError {
                    result(
                        FlutterError.fromAdaptyError(adaptyError, method: methodName)
                    )
                } else {
                    // TODO: inspect
                    result(
                        FlutterError.unknown(originalError: error)
                    )
                }
            }
        }
    }
}

 extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
    public func didLoadLatestProfile(_ profile: AdaptyProfile) {
        guard let data = try? SwiftAdaptyFlutterPlugin.jsonEncoder.encode(profile) else { return }
        Self.channel?.invokeMethod(MethodName.didUpdateProfile.rawValue, arguments: String(data: data, encoding: .utf8))
    }
 }

extension FlutterError {
    static let adaptyErrorCode = "adapty_flutter_ios"

    static let adaptyErrorMessageKey = "message"
    static let adaptyErrorDetailKey = "detail"
    static let adaptyErrorCodeKey = "adapty_code"

    static func unknown(
        originalError: Error
    ) -> FlutterError {
        return FlutterError(
            code: adaptyErrorCode,
            message: originalError.localizedDescription,
            details: nil
        )
    }

    static func missingParameter(
        name: String,
        method: String,
        originalError: Error?
    ) -> FlutterError {
        let message = "Error while parsing parameter '\(name)'"
        let detail = "Method: \(method), Parameter: \(name), OriginalError: \(originalError?.localizedDescription ?? "null")"

        return FlutterError(
            code: adaptyErrorCode,
            message: message,
            details: [
                adaptyErrorCodeKey: AdaptyError.ErrorCode.decodingFailed,
                adaptyErrorMessageKey: message,
                adaptyErrorDetailKey: detail
            ]
        )
    }

    static func encoder(method: String, originalError: Error) -> FlutterError {
        let message = originalError.localizedDescription
        let detail = "Method: \(method))"

        return FlutterError(
            code: adaptyErrorCode,
            message: message,
            details: [
                adaptyErrorCodeKey: AdaptyError.ErrorCode.encodingFailed,
                adaptyErrorMessageKey: message,
                adaptyErrorDetailKey: detail
            ]
        )
    }

    static func fromAdaptyError(
        _ adaptyError: AdaptyError,
        method: String
    ) -> FlutterError {
        do {
            let adaptyErrorData = try SwiftAdaptyFlutterPlugin.jsonEncoder.encode(adaptyError)
            let adaptyErrorString = String(data: adaptyErrorData, encoding: .utf8)

            return FlutterError(
                code: adaptyErrorCode,
                message: adaptyError.localizedDescription,
                details: adaptyErrorString
            )
        } catch {
            return .encoder(
                method: method,
                originalError: error
            )
        }
    }
}
