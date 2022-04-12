library adapty_flutter;

import 'src/plugin/adapty_legacy.dart';

export 'src/models.dart';

@Deprecated('Please, use `Adapty.instance` from `adapty_flutter.dart`')
// ignore: deprecated_member_use_from_same_package
typedef Adapty = AdaptyLegacy;
