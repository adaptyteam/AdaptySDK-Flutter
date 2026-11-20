import 'dart:math' show Random;

import 'adapty_native_transport.dart';
import 'adapty_platform_info.dart';
import 'app_message_id.dart';

/// What a runtime takes from the outside world.
final class AdaptyRuntimeEnvironment {
  /// App message ids come from [newMessageId], random version 4 UUIDs when it is null.
  AdaptyRuntimeEnvironment({required this.transport, required this.platform, String Function()? newMessageId})
    : newMessageId = newMessageId ?? _randomMessageIds();

  final AdaptyNativeTransport transport;

  final AdaptyPlatformInfo platform;

  /// Makes the id the script receives with an app message.
  final String Function() newMessageId;

  /// Random version 4 UUIDs from one secure generator, created on the first message.
  static String Function() _randomMessageIds() {
    Random? random;
    return () => newAppMessageId(random ??= Random.secure());
  }
}
