import 'adapty_native_transport.dart';

/// What a runtime takes from the outside world.
final class AdaptyRuntimeEnvironment {
  AdaptyRuntimeEnvironment({required this.transport});

  final AdaptyNativeTransport transport;
}
