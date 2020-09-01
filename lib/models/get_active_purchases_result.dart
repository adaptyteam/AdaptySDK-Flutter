import 'package:adapty_flutter/models/adapty_result.dart';

class GetActivePurchasesResult extends AdaptyResult {
  final bool activeSubscription;
  final List<String> nonSubscriptionsProductIds;
  final String activeSubscriptionProductId;

  GetActivePurchasesResult(
      this.activeSubscription, this.nonSubscriptionsProductIds,
      {this.activeSubscriptionProductId, errorCode, errorMessage})
      : super(errorCode: errorCode, errorMessage: errorMessage);

  GetActivePurchasesResult.fromJson(Map<String, dynamic> json)
      : activeSubscription =
            json[_GetActivePurchasesResultKeys._activeSubscription] as bool,
        nonSubscriptionsProductIds = List<String>.from(
            json[_GetActivePurchasesResultKeys._nonSubscriptionsProductIds]),
        activeSubscriptionProductId = json[_GetActivePurchasesResultKeys
                    ._activeSubscriptionProductId] ==
                null
            ? null
            : json[_GetActivePurchasesResultKeys._activeSubscriptionProductId]
                as String;

  @override
  String toString() {
    return '${_GetActivePurchasesResultKeys._activeSubscription}: $activeSubscription; '
        '${_GetActivePurchasesResultKeys._activeSubscriptionProductId}: $activeSubscriptionProductId; '
        '${_GetActivePurchasesResultKeys._nonSubscriptionsProductIds}: ${nonSubscriptionsProductIds.join(', ')}';
  }
}

class _GetActivePurchasesResultKeys {
  static const _activeSubscription = "activeSubscription";
  static const _activeSubscriptionProductId = "activeSubscriptionProductId";
  static const _nonSubscriptionsProductIds = "nonSubscriptionsProductIds";
}
