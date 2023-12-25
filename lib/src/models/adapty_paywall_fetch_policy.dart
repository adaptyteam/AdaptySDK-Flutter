//
//  adapty_paywall_fetch_policy.dart
//  Adapty
//
//  Created by Aleksei Valiano on 12.12.2023.
//

import 'package:meta/meta.dart' show immutable;

part 'private/adapty_paywall_fetch_policy_json_builder.dart';

@immutable
class AdaptyPaywallFetchPolicy {
  final String _type;
  final Duration? _maxAge;

  const AdaptyPaywallFetchPolicy._( this._type, this._maxAge );

  static const reloadRevalidatingCacheData = AdaptyPaywallFetchPolicy._(_Values.reloadRevalidatingCacheData, null);
  static const returnCacheDataElseLoad = AdaptyPaywallFetchPolicy._(_Values.returnCacheDataElseLoad, null);
  const AdaptyPaywallFetchPolicy.returnCacheDataIfNotExpiredElseLoad(Duration maxAge) : this._(_Values.returnCacheDataIfNotExpiredElseLoad, maxAge);

  String toString() => '(_type: $_type, _max_age: $_maxAge)';
}
