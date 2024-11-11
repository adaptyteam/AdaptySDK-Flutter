import 'package:meta/meta.dart' show immutable;
import 'dart:convert' show json;
import 'private/json_builder.dart';
import 'adapty_locale.dart';

part 'private/adapty_paywall_remote_config_json.dart';

@immutable
class AdaptyPaywallRemoteConfig {
  final AdaptyLocale _adaptyLocale;
  final String jsonString;

  const AdaptyPaywallRemoteConfig._(
    this._adaptyLocale,
    this.jsonString,
  );

  String get locale => _adaptyLocale.id;

  /// A custom dictionary configured in Adapty Dashboard for this paywall (same as `jsonString`)
  Map<String, dynamic>? get dictionary {
    if (jsonString.isEmpty) return null;
    return json.decode(jsonString);
  }
}
