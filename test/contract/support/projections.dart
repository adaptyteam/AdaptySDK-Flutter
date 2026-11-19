// The public fields of the models the SDK decodes from the native side, as plain maps a test can compare with a
// literal: only what an app can read, nothing private to the SDK.
import 'package:adapty_flutter/adapty_flutter.dart';

Map<String, Object?> projectProfile(AdaptyProfile p) => {
  'profileId': p.profileId,
  'customerUserId': p.customerUserId,
  'customAttributes': p.customAttributes,
  'accessLevels': {for (final MapEntry(:key, :value) in p.accessLevels.entries) key: projectAccessLevel(value)},
  'subscriptions': {for (final MapEntry(:key, :value) in p.subscriptions.entries) key: projectSubscription(value)},
  'nonSubscriptions': {
    for (final MapEntry(:key, :value) in p.nonSubscriptions.entries) key: [for (final n in value) _nonSubscription(n)],
  },
  'appliedExternalAttributionProviders': [for (final a in p.appliedExternalAttributionProviders) a.rawValue],
  'isTestUser': p.isTestUser,
};

Map<String, Object?> projectAccessLevel(AdaptyAccessLevel a) => {
  'id': a.id,
  'isActive': a.isActive,
  'vendorProductId': a.vendorProductId,
  'store': a.store,
  'activatedAt': a.activatedAt,
  'renewedAt': a.renewedAt,
  'expiresAt': a.expiresAt,
  'isLifetime': a.isLifetime,
  'activeIntroductoryOfferType': a.activeIntroductoryOfferType,
  'activePromotionalOfferType': a.activePromotionalOfferType,
  'activePromotionalOfferId': a.activePromotionalOfferId,
  'offerId': a.offerId,
  'willRenew': a.willRenew,
  'isInGracePeriod': a.isInGracePeriod,
  'unsubscribedAt': a.unsubscribedAt,
  'billingIssueDetectedAt': a.billingIssueDetectedAt,
  'startsAt': a.startsAt,
  'cancellationReason': a.cancellationReason,
  'isRefund': a.isRefund,
  'billingPlan': a.billingPlan?.value,
  'commitmentInfo': _commitment(a.commitmentInfo),
};

Map<String, Object?> projectSubscription(AdaptySubscription s) => {
  'store': s.store,
  'vendorProductId': s.vendorProductId,
  'vendorTransactionId': s.vendorTransactionId,
  'vendorOriginalTransactionId': s.vendorOriginalTransactionId,
  'isActive': s.isActive,
  'isLifetime': s.isLifetime,
  'activatedAt': s.activatedAt,
  'renewedAt': s.renewedAt,
  'expiresAt': s.expiresAt,
  'startsAt': s.startsAt,
  'unsubscribedAt': s.unsubscribedAt,
  'billingIssueDetectedAt': s.billingIssueDetectedAt,
  'isInGracePeriod': s.isInGracePeriod,
  'isSandbox': s.isSandbox,
  'isRefund': s.isRefund,
  'willRenew': s.willRenew,
  'activeIntroductoryOfferType': s.activeIntroductoryOfferType,
  'activePromotionalOfferType': s.activePromotionalOfferType,
  'activePromotionalOfferId': s.activePromotionalOfferId,
  'offerId': s.offerId,
  'cancellationReason': s.cancellationReason,
  'billingPlan': s.billingPlan?.value,
  'commitmentInfo': _commitment(s.commitmentInfo),
};

Map<String, Object?>? _commitment(AdaptyProfileSubscriptionCommitmentInfo? c) => c == null
    ? null
    : {
        'billingPeriodNumber': c.billingPeriodNumber,
        'totalBillingPeriods': c.totalBillingPeriods,
        'expiresAt': c.expiresAt,
      };

Map<String, Object?> _nonSubscription(AdaptyNonSubscription n) => {
  'purchaseId': n.purchaseId,
  'store': n.store,
  'vendorProductId': n.vendorProductId,
  'vendorTransactionId': n.vendorTransactionId,
  'purchasedAt': n.purchasedAt,
  'isSandbox': n.isSandbox,
  'isRefund': n.isRefund,
  'isConsumable': n.isConsumable,
};

Map<String, Object?> projectProduct(AdaptyPaywallProduct p) => {
  'vendorProductId': p.vendorProductId,
  'flowProductId': p.flowProductId,
  'accessLevelId': p.accessLevelId,
  'productType': p.productType,
  'paywallVariationId': p.paywallVariationId,
  'paywallABTestName': p.paywallABTestName,
  'paywallName': p.paywallName,
  'localizedDescription': p.localizedDescription,
  'localizedTitle': p.localizedTitle,
  'isFamilyShareable': p.isFamilyShareable,
  'regionCode': p.regionCode,
  'price': projectPrice(p.price),
  'subscription': _productSubscription(p.subscription),
  'paywallProductIndex': p.paywallProductIndex,
};

Map<String, Object?> projectPrice(AdaptyPrice p) => {
  'amount': p.amount,
  'currencyCode': p.currencyCode,
  'currencySymbol': p.currencySymbol,
  'localizedString': p.localizedString,
};

Map<String, Object?> _period(AdaptySubscriptionPeriod p) => {'unit': p.unit, 'numberOfUnits': p.numberOfUnits};

Map<String, Object?>? _productSubscription(AdaptyProductSubscription? s) => s == null
    ? null
    : {
        'groupIdentifier': s.groupIdentifier,
        'period': _period(s.period),
        'localizedPeriod': s.localizedPeriod,
        'offer': _offer(s.offer),
        'renewalType': s.renewalType,
        'basePlanId': s.basePlanId,
        'pricingTerms': _pricingTerms(s.pricingTerms),
      };

Map<String, Object?>? _offer(AdaptySubscriptionOffer? o) => o == null
    ? null
    : {
        'identifier': {'id': o.identifier.id, 'type': o.identifier.type},
        'phases': [
          for (final phase in o.phases)
            {
              'price': projectPrice(phase.price),
              'numberOfPeriods': phase.numberOfPeriods,
              'paymentMode': phase.paymentMode,
              'subscriptionPeriod': _period(phase.subscriptionPeriod),
              'localizedSubscriptionPeriod': phase.localizedSubscriptionPeriod,
              'localizedNumberOfPeriods': phase.localizedNumberOfPeriods,
              'identifier': phase.identifier,
            },
        ],
        'offerTags': o.offerTags,
      };

Map<String, Object?>? _pricingTerms(AdaptySubscriptionPricingTerms? t) => t == null
    ? null
    : {
        'billingPlan': t.billingPlan.value,
        'billingPrice': projectPrice(t.billingPrice),
        'billingPeriod': _period(t.billingPeriod),
        'commitmentInfo': {'price': projectPrice(t.commitmentInfo.price), 'period': _period(t.commitmentInfo.period)},
      };

Map<String, Object?> projectFlow(AdaptyFlow f) => {
  'placement': _placement(f.placement),
  'instanceIdentity': f.instanceIdentity,
  'name': f.name,
  'variationId': f.variationId,
  'variationName': f.variationName,
  'remoteConfigs': [
    for (final c in f.remoteConfigs) {'locale': c.locale, 'data': c.data, 'dictionary': c.dictionary},
  ],
  'paywalls': [
    for (final p in f.paywalls)
      {
        'placement': _placement(p.placement),
        'instanceIdentity': p.instanceIdentity,
        'name': p.name,
        'variationId': p.variationId,
        'productIdentifiers': [for (final i in p.productIdentifiers) _productIdentifier(i)],
      },
  ],
  'hasViewConfiguration': f.hasViewConfiguration,
  'productIdentifiers': [for (final i in f.productIdentifiers) _productIdentifier(i)],
};

Map<String, Object?> _placement(AdaptyPlacement p) => {
  'id': p.id,
  'audienceName': p.audienceName,
  'revision': p.revision,
  'abTestName': p.abTestName,
  'placementAudienceVersionId': p.placementAudienceVersionId,
  'isTrackingPurchases': p.isTrackingPurchases,
};

Map<String, Object?> _productIdentifier(AdaptyProductIdentifier i) => {
  'vendorProductId': i.vendorProductId,
  'basePlanId': i.basePlanId,
};

Map<String, Object?> projectPurchaseResult(AdaptyPurchaseResult r) => switch (r) {
  AdaptyPurchaseResultPending() => {'result': 'pending'},
  AdaptyPurchaseResultUserCancelled() => {'result': 'user cancelled'},
  AdaptyPurchaseResultSuccess() => {
    'result': 'success',
    'profile': projectProfile(r.profile),
    'appleJwsTransaction': r.appleJwsTransaction,
    'googlePurchaseToken': r.googlePurchaseToken,
  },
};

Map<String, Object?> projectInstallationStatus(AdaptyInstallationStatus s) => switch (s) {
  AdaptyInstallationStatusNotAvailable() => {'status': 'not available'},
  AdaptyInstallationStatusNotDetermined() => {'status': 'not determined'},
  AdaptyInstallationStatusDetermined(:final details) => {
    'status': 'determined',
    'details': {
      'installId': details.installId,
      'installTime': details.installTime,
      'appLaunchCount': details.appLaunchCount,
      'payload': details.payload,
    },
  },
};

Map<String, Object?> projectError(AdaptyError e) => {'code': e.code, 'message': e.message, 'detail': e.detail};
