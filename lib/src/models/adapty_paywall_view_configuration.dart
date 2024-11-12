import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/adapty_paywall_view_configuration_json.dart';

@immutable
class AdaptyPaywallViewConfiguration {
  final String paywallBuilderId;
  final String locale;

  const AdaptyPaywallViewConfiguration._(this.paywallBuilderId, this.locale);
}
