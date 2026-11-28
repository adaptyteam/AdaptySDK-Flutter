import 'adapty_log_sink.dart';
import 'adapty_native_transport.dart';
import 'adapty_platform_info.dart';

/// What a runtime takes from the outside world.
final class AdaptyRuntimeEnvironment {
  /// App message ids come from [newMessageId], six random characters from `0-9A-Za-z` when it is null.
  AdaptyRuntimeEnvironment({required this.transport, required this.platform, String Function()? newMessageId})
    : newMessageId = newMessageId ?? _randomMessageId;

  final AdaptyNativeTransport transport;

  final AdaptyPlatformInfo platform;

  /// Makes the id the script receives with an app message.
  final String Function() newMessageId;

  static String _randomMessageId() => randomStamp(6);
}
