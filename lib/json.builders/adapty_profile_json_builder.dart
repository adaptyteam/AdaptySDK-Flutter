//
//  adapty_profile_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

part of '../models/adapty_profile.dart';

extension AdaptyProfileJSONBuilder on AdaptyProfile {
  static AdaptyProfile fromJsonValue(Map<String, dynamic> json) {
    return AdaptyProfile._(
      json.string(_Keys.profileId),
      json.stringIfPresent(_Keys.customerUserId),
      json.objectIfPresent(_Keys.customAttributes) ?? <String, dynamic>{},
      json.accessLevelDictionaryIfPresent(_Keys.accessLevels) ?? <String, AdaptyAccessLevel>{},
      json.subscriptionIfPresent(_Keys.subscriptions) ?? <String, AdaptySubscription>{},
      json.nonSubscriptionDictionaryIfPresent(_Keys.nonSubscriptions) ?? <String, List<AdaptyNonSubscription>>{},
    );
  }
}

class _Keys {
  static const profileId = 'profile_id';
  static const customerUserId = 'customer_user_id';
  static const customAttributes = 'custom_attributes';
  static const accessLevels = 'paid_access_levels';
  static const subscriptions = 'subscriptions';
  static const nonSubscriptions = 'non_subscriptions';
}
