//
//  AdaptyProfile.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import '../entities.json/JSONBuilder.dart';
import 'AdaptyAccessLevel.dart';
import 'AdaptyNonSubscription.dart';
import 'AdaptySubscription.dart';

part '../entities.json/AdaptyProfileJSONBuilder.dart';

@immutable
class AdaptyProfile {
  /// An identifier of a user in Adapty.
  final String profileId;

  /// An identifier of a user in your system.
  /// 
  /// [Nullable]
  final String? customerUserId;

  /// Previously set user custom attributes with `.updateProfile()` method.
  final Map<String, dynamic> customAttributes;

  /// The keys are access level identifiers configured by you in Adapty Dashboard. 
  /// The values are Can be null if the customer has no access levels.
  final Map<String, AdaptyAccessLevel> accessLevels;

  /// The keys are product ids from a store. The values are information about subscriptions. 
  /// Can be null if the customer has no subscriptions.
  final Map<String, AdaptySubscription> subscriptions;

  /// The keys are product ids from the store. The values are arrays of information about consumables. 
  /// Can be null if the customer has no purchases.
  final Map<String, List<AdaptyNonSubscription>> nonSubscriptions;

  const AdaptyProfile._(
    this.profileId,
    this.customerUserId,
    this.customAttributes,
    this.accessLevels,
    this.subscriptions,
    this.nonSubscriptions,
  );

  @override
  String toString() => '(profileId: $profileId, '
      'customerUserId: $customerUserId, '
      'customAttributes: $customAttributes, '
      'accessLevels: $accessLevels, '
      'subscriptions: $subscriptions, '
      'nonSubscriptions: $nonSubscriptions)';
}
