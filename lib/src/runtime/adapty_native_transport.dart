import 'package:flutter/services.dart';

/// The name of the method channel between this package and the native SDKs.
const String adaptyChannelName = 'flutter.adapty.com/adapty';

/// Handles an event sent by the native side: [eventName] is the name of the call on the channel, [jsonPayload] its
/// arguments as a JSON string. What the returned future completes with is the reply to the native side.
typedef AdaptyEventHandler = Future<Object?> Function(String eventName, String jsonPayload);

/// The way to the native SDKs: a JSON string goes out with each call and a JSON string comes back.
abstract interface class AdaptyNativeTransport {
  /// Calls [method] on the native side with [jsonArgs] and returns its reply.
  Future<String?> invoke(String method, String jsonArgs);

  /// Sends every event of the native side to [handler]; null stops the delivery.
  void setEventHandler(AdaptyEventHandler? handler);
}

/// The transport over a [MethodChannel], the adapty channel unless told otherwise.
final class MethodChannelTransport implements AdaptyNativeTransport {
  const MethodChannelTransport([this.channel = const MethodChannel(adaptyChannelName)]);

  final MethodChannel channel;

  @override
  Future<String?> invoke(String method, String jsonArgs) => channel.invokeMethod<String>(method, jsonArgs);

  @override
  void setEventHandler(AdaptyEventHandler? handler) {
    if (handler == null) {
      channel.setMethodCallHandler(null);
      return;
    }
    // The native SDKs always send a JSON string; anything else reaches the handler as the JSON null.
    channel.setMethodCallHandler((call) {
      final arguments = call.arguments;
      return handler(call.method, arguments is String ? arguments : 'null');
    });
  }
}
