import 'plugin/adapty_native.dart';
import 'plugin/adapty_plugin.dart';

abstract class Adapty {
  static final AdaptyPlugin instance = AdaptyNative();

  Adapty._();
}
