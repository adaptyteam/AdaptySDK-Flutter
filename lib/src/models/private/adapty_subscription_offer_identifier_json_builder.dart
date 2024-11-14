part of '../adapty_subscription_offer_identifier.dart';

extension AdaptySubscriptionOfferIdentifierJSONBuilder on AdaptySubscriptionOfferIdentifier {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.type: type.name,
      };

  static AdaptySubscriptionOfferIdentifier fromJsonValue(Map<String, dynamic> json) {
    return AdaptySubscriptionOfferIdentifier._(
      json.stringIfPresent(_Keys.id),
      AdaptySubscriptionOfferType.values.byName(json.string(_Keys.type)),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const type = 'type';
}

extension MapExtension on Map<String, dynamic> {
  AdaptySubscriptionOfferIdentifier subscriptionOfferIdentifier(String key) {
    var value = this[key];
    return AdaptySubscriptionOfferIdentifierJSONBuilder.fromJsonValue(value);
  }
}
