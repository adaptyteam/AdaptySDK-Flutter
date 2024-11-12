import 'package:meta/meta.dart' show immutable;
import 'dart:convert' show json;
import 'private/json_builder.dart';

part 'private/adapty_paywall_remote_config_json.dart';

@immutable
class AdaptyPaywallRemoteConfig {
  final String locale;
  final String data;

  const AdaptyPaywallRemoteConfig._(
    this.locale,
    this.data,
  );

  /// A custom dictionary configured in Adapty Dashboard for this paywall (same as `data`)
  Map<String, dynamic>? get dictionary {
    if (data.isEmpty) return null;
    return json.decode(data);
  }
}
