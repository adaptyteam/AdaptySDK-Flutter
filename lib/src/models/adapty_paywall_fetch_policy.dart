//
//  adapty_paywall_fetch_policy.dart
//  Adapty
//
//  Created by Aleksei Valiano on 12.12.2023.
//

part 'private/adapty_paywall_fetch_policy_json_builder.dart';

sealed class AdaptyPaywallFetchPolicy {
  static AdaptyPaywallFetchPolicy reloadRevalidatingCacheData = ReloadRevalidatingCacheData();
  static AdaptyPaywallFetchPolicy returnCacheDataElseLoad = ReturnCacheDataElseLoad();
  static AdaptyPaywallFetchPolicy returnCacheDataIfNotExpiredElseLoad(Duration maxAge) => ReturnCacheDataIfNotExpiredElseLoad(maxAge);
}

final class ReloadRevalidatingCacheData extends AdaptyPaywallFetchPolicy {}

final class ReturnCacheDataElseLoad extends AdaptyPaywallFetchPolicy {}

final class ReturnCacheDataIfNotExpiredElseLoad extends AdaptyPaywallFetchPolicy {
  final Duration maxAge;

  ReturnCacheDataIfNotExpiredElseLoad(this.maxAge);
}
