import 'adapty_native_transport.dart';
import 'adapty_platform_info.dart';

/// What a runtime takes from the outside world.
final class AdaptyRuntimeEnvironment {
  AdaptyRuntimeEnvironment({required this.transport, required this.platform});

  final AdaptyNativeTransport transport;

  final AdaptyPlatformInfo platform;
}
