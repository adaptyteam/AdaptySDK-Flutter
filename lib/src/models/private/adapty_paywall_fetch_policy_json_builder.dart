//
//  adapty_paywall_fetch_policy_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 12.12.2023.
//

part of '../adapty_paywall_fetch_policy.dart';

extension AdaptyPaywallFetchPolicyJSONBuilder on AdaptyPaywallFetchPolicy {
  dynamic get jsonValue => {
        _Keys.type: _type,
        if (_maxAge != null) _Keys.maxAge: _maxAge!.inMilliseconds.toDouble() / 1000.0,
      };
}

class _Keys {
  static const type = 'type';
  static const maxAge = 'max_age';
}

class _Values {
  static const reloadRevalidatingCacheData = 'reload_revalidating_cache_data';
  static const returnCacheDataElseLoad = 'return_cache_data_else_load';
  static const returnCacheDataIfNotExpiredElseLoad = 'return_cache_data_if_not_expired_else_load';
}
