part of '../adaptyui/adaptyui_paywall_view.dart';

extension AdaptyUIPaywallViewJSONBuilder on AdaptyUIPaywallView {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.placementId: placementId,
        _Keys.variationId: variationId,
      };

  static AdaptyUIPaywallView fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIPaywallView._(
      json.string(_Keys.id),
      json.string(_Keys.placementId),
      json.string(_Keys.variationId),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const placementId = 'placement_id';
  static const variationId = 'variation_id';
}
