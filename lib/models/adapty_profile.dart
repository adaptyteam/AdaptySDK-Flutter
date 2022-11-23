import 'dart:core';

import '../models/adapty_access_level_info.dart';
import '../models/adapty_non_subscription_info.dart';
import '../models/adapty_subscription_info.dart';

class AdaptyProfile {
  /// An identifier of the user in Adapty
  final String profileId;

  /// An identifier of the user in your system.
  ///
  /// [Nullable]
  final String? customerUserId;

  /// The keys are access level identifiers configured by you in Adapty Dashboard.
  /// The values are [AdaptyAccessLevelInfo] objects.
  /// Can be null if the customer has no access levels.
  final Map<String, AdaptyAccessLevelInfo> accessLevels;

  /// The keys are product ids from App Store Connect.
  /// The values are [AdaptySubscriptionInfo] objects.
  /// Can be null if the customer has no subscriptions.
  final Map<String, AdaptySubscriptionInfo> subscriptions;

  /// The keys are product ids from App Store Connect.
  /// The values are array[] of [AdaptyNonSubscriptionInfo] objects.
  /// Can be null if the customer has no purchases.
  final Map<String, List<AdaptyNonSubscriptionInfo>> nonSubscriptions;

  AdaptyProfile.fromMap(Map<String, dynamic> map)
      : profileId = map[_Keys.profileId],
        customerUserId = map[_Keys.customerUserId],
        accessLevels = map[_Keys.accessLevels] == null ? <String, AdaptyAccessLevelInfo>{} : (map[_Keys.accessLevels] as Map).map((key, value) => MapEntry(key, AdaptyAccessLevelInfo.fromJson(value))),
        subscriptions =
            map[_Keys.subscriptions] == null ? <String, AdaptySubscriptionInfo>{} : (map[_Keys.subscriptions] as Map).map((key, value) => MapEntry(key, AdaptySubscriptionInfo.fromJson(value))),
        nonSubscriptions = map[_Keys.nonSubscriptions] == null
            ? <String, List<AdaptyNonSubscriptionInfo>>{}
            : (map[_Keys.nonSubscriptions] as Map).map((key, list) => MapEntry(key, (list as List).map((e) => AdaptyNonSubscriptionInfo.fromJson(e)).toList()));

  @override
  String toString() => '${_Keys.customerUserId}: $customerUserId, '
      '${_Keys.accessLevels}: $accessLevels, '
      '${_Keys.subscriptions}: $subscriptions, '
      '${_Keys.nonSubscriptions}: $nonSubscriptions';
}

class _Keys {
  static const String profileId = "profile_id";
  static const String customerUserId = "customerUserId";
  static const String accessLevels = "paid_access_levels";
  static const String subscriptions = "subscriptions";
  static const String nonSubscriptions = "non_subscriptions";
}
